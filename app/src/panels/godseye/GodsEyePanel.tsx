import { useCallback, useEffect, useRef, useState, type KeyboardEvent } from "react";
import * as Cesium from "cesium";
import styles from "./GodsEyePanel.module.css";
import { createApplicationViewer, installTrackpadPinchZoom } from "./gev/viewer.js";
import {
  installRenderGovernor,
  uninstallRenderGovernor,
  governorRequestRender,
} from "./gev/renderGovernor.js";
import { createMapCredits } from "./gev/maps/credits.js";
import {
  createDefaultMapSources,
  findMapSource,
  resolveStackId,
} from "./gev/maps/defaultSources.js";
import { createFleetSnapshotSource } from "./layers/fleetSource.js";
import { createFleetNodesLayer, type FleetNodesLayer } from "./layers/fleetNodes.js";
import { ESRI_TILE_HOST, OSM_TILE_HOST } from "./gev/maps/imagery.js";
import { observeGodsEyeTheme, readGodsEyeThemeColors } from "./theme.js";
import { useCockpitStore } from "../../stores/cockpit.js";
import { ComputersPanelContent } from "../../components/panels/ComputersPanelContent";

function remoteHostForStack(stackId: string): string | null {
  if (stackId === "esri-imagery") return ESRI_TILE_HOST;
  if (stackId === "osm") return OSM_TILE_HOST;
  return null;
}

declare global {
  interface Window {
    __cockpitGodsEye?: {
      ready: boolean;
      entityCount: number;
      liveViewers: number;
      unplaced: number;
    };
  }
}

/** Viewers currently holding a WebGL context (created and not yet destroyed). */
let liveViewerCount = 0;

type NodeRow = { id: string; name: string; geo?: { lat: number; lon: number } };

/** Camera altitude that frames the whole globe in the panel. */
const GLOBE_VIEW_ALTITUDE_M = 20_000_000;

function prefersReducedMotion(): boolean {
  return typeof window.matchMedia === "function"
    && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

async function applyMapStack(
  viewer: Cesium.Viewer,
  stackId: string,
  credits: ReturnType<typeof createMapCredits>,
) {
  const config = createDefaultMapSources();
  const resolved = resolveStackId(config, stackId);
  const entry = findMapSource(config, resolved);
  if (!entry) throw new Error(`unknown stack ${stackId}`);
  const imageryProvider = (await entry.imagery()) as Cesium.ImageryProvider;
  const terrainBundle = await entry.terrain.create({});
  if (viewer.isDestroyed()) return;
  viewer.imageryLayers.removeAll();
  viewer.imageryLayers.addImageryProvider(imageryProvider);
  viewer.terrainProvider = terrainBundle.provider as Cesium.TerrainProvider;
  credits.show(typeof entry.credit === "string" ? entry.credit : null);
  governorRequestRender("map-stack");
}

/** The viewer's own WebGL context (getContext with its type returns the existing one). */
function viewerContext(viewer: Cesium.Viewer): WebGLRenderingContext | WebGL2RenderingContext | null {
  const canvas = viewer.scene.canvas;
  return canvas.getContext("webgl2") ?? canvas.getContext("webgl");
}

/** True once the element has a real layout box (not display:none / collapsed flex child). */
function hasLayoutBox(el: HTMLElement): boolean {
  return el.clientWidth > 0 && el.clientHeight > 0;
}

export default function GodsEyePanel() {
  const canvasRef = useRef<HTMLDivElement>(null);
  const creditRef = useRef<HTMLDivElement>(null);
  const viewerRef = useRef<Cesium.Viewer | null>(null);
  const layerRef = useRef<FleetNodesLayer | null>(null);
  const creditsRef = useRef<ReturnType<typeof createMapCredits> | null>(null);
  const [stackId, setStackId] = useState("naturalearth");
  const stackIdRef = useRef(stackId);
  const [pendingStack, setPendingStack] = useState<string | null>(null);
  const [ready, setReady] = useState(false);
  const [placed, setPlaced] = useState<NodeRow[]>([]);
  const [unplaced, setUnplaced] = useState<NodeRow[]>([]);
  const [arcCount, setArcCount] = useState(0);
  const [loadError, setLoadError] = useState<string | null>(null);
  const setSelectedComputer = useCockpitStore((s) => s.setSelectedComputer);
  const selectedComputerId = useCockpitStore((s) => s.selectedComputerId);
  // The mount effect must run exactly once per panel mount: callbacks it needs
  // are read through refs so a re-render never tears the viewer down.
  const selectRef = useRef(setSelectedComputer);
  selectRef.current = setSelectedComputer;

  useEffect(() => {
    const canvasHost = canvasRef.current;
    const creditHost = creditRef.current;
    if (!canvasHost || !creditHost) return;
    let disposed = false;
    let poll: number | null = null;
    let disposePinch: (() => void) | null = null;
    let waitForLayout: ResizeObserver | null = null;
    let publishedReady = false;

    const publish = (diag?: { placed: number; unplaced: number }) => {
      window.__cockpitGodsEye = {
        ready: publishedReady,
        entityCount: diag?.placed ?? 0,
        liveViewers: liveViewerCount,
        unplaced: diag?.unplaced ?? 0,
      };
    };

    const syncFromLayer = (layer: FleetNodesLayer) => {
      const d = layer.getDiagnostics();
      setPlaced(d.placedRows.map((n) => ({ id: n.id, name: n.name, geo: n.geo })));
      setUnplaced(d.unplacedRows.map((n) => ({ id: n.id, name: n.name })));
      setArcCount(d.arcs);
      publish({ placed: d.placed, unplaced: d.unplaced });
      return d;
    };

    const start = async () => {
      const viewer = createApplicationViewer({ container: canvasHost, creditContainer: creditHost });
      liveViewerCount += 1;
      viewerRef.current = viewer;
      publish();
      disposePinch = installTrackpadPinchZoom(viewer);
      installRenderGovernor(viewer);
      viewer.scene.backgroundColor =
        Cesium.Color.fromCssColorString(readGodsEyeThemeColors().bg) ?? viewer.scene.backgroundColor;
      const credits = createMapCredits(viewer);
      creditsRef.current = credits;
      await applyMapStack(viewer, stackIdRef.current, credits);
      if (disposed) return;

      const layer = createFleetNodesLayer({
        source: createFleetSnapshotSource(),
        host: {
          onSelectComputer: (id) => selectRef.current(id),
          readThemeColors: () => {
            const t = readGodsEyeThemeColors();
            return { accent: t.accent, active: t.active, text: t.text };
          },
          // Placement (explicit > COCKPIT_NODE_GEO > tz centroid) is resolved
          // server-side in app/server/fleet/nodes.ts; the client never guesses.
          tzCentroids: {},
          localTz: Intl.DateTimeFormat().resolvedOptions().timeZone,
          nodeGeoEnv: "",
        },
      });
      layerRef.current = layer;
      layer.init(viewer);
      layer.enable();
      await layer.update();
      if (disposed) return;
      const d = syncFromLayer(layer);
      const local = d.placedRows.find((n) => n.id === "local") ?? d.placedRows[0];
      if (local) {
        viewer.camera.setView({
          destination: Cesium.Cartesian3.fromDegrees(local.geo.lon, local.geo.lat, GLOBE_VIEW_ALTITUDE_M),
        });
      }
      governorRequestRender("fleet-initial");
      publishedReady = true;
      setReady(true);
      publish({ placed: d.placed, unplaced: d.unplaced });
      poll = window.setInterval(() => {
        void layer
          .update()
          .then((changed) => {
            if (changed && !disposed) syncFromLayer(layer);
          })
          .catch((error: unknown) => console.warn("[GodsEye] fleet update failed", error));
      }, layer.updateInterval);
    };

    const begin = () => {
      start().catch((error: unknown) => {
        if (!disposed) setLoadError(error instanceof Error ? error.message : String(error));
      });
    };

    // Cesium sizes its drawing buffer from the container's client box. Inside
    // the dockview multiview the panel body can mount before layout (or in a
    // hidden tab) with a 0×0 box, so defer viewer creation until the
    // container really has width and height instead of failing.
    if (hasLayoutBox(canvasHost)) {
      begin();
    } else {
      waitForLayout = new ResizeObserver(() => {
        if (disposed || !hasLayoutBox(canvasHost)) return;
        waitForLayout?.disconnect();
        waitForLayout = null;
        begin();
      });
      waitForLayout.observe(canvasHost);
    }

    return () => {
      disposed = true;
      waitForLayout?.disconnect();
      waitForLayout = null;
      if (poll !== null) window.clearInterval(poll);
      layerRef.current?.destroy();
      layerRef.current = null;
      creditsRef.current?.destroy();
      creditsRef.current = null;
      disposePinch?.();
      const viewer = viewerRef.current;
      viewerRef.current = null;
      if (viewer) {
        uninstallRenderGovernor(viewer);
        const gl = viewerContext(viewer);
        if (!viewer.isDestroyed()) viewer.destroy();
        // viewer.destroy() leaves the WebGL context to GC. Browsers cap live
        // contexts (and SwiftShader runs out sooner); a later viewer then gets a
        // dead context whose limits read 0, and Cesium stops rendering with
        // "lineWidth out of range" / "maximum texture size (0)". Free it now.
        gl?.getExtension("WEBGL_lose_context")?.loseContext();
        liveViewerCount = Math.max(0, liveViewerCount - 1);
      }
      publishedReady = false;
      publish();
    };
  }, []);

  useEffect(() => {
    if (stackIdRef.current === stackId) return;
    stackIdRef.current = stackId;
    const viewer = viewerRef.current;
    const credits = creditsRef.current;
    if (!viewer || !credits || !ready) return;
    applyMapStack(viewer, stackId, credits).catch((error: unknown) => {
      setLoadError(error instanceof Error ? error.message : String(error));
    });
  }, [stackId, ready]);

  useEffect(() => {
    const stop = observeGodsEyeTheme(() => {
      const viewer = viewerRef.current;
      if (viewer && !viewer.isDestroyed()) {
        const bg = Cesium.Color.fromCssColorString(readGodsEyeThemeColors().bg);
        if (bg) viewer.scene.backgroundColor = bg;
      }
      layerRef.current?.getDiagnostics().applyThemeColors();
      governorRequestRender("theme");
    });
    return stop;
  }, []);

  const focusNode = useCallback(
    (row: NodeRow) => {
      setSelectedComputer(row.id);
      layerRef.current?.select(row.id);
      const viewer = viewerRef.current;
      if (!viewer || viewer.isDestroyed() || !row.geo) return;
      viewer.camera.flyTo({
        destination: Cesium.Cartesian3.fromDegrees(row.geo.lon, row.geo.lat, GLOBE_VIEW_ALTITUDE_M / 2),
        duration: prefersReducedMotion() ? 0 : 1.2,
      });
      governorRequestRender("fleet-focus");
    },
    [setSelectedComputer],
  );

  const onRailKeyDown = (event: KeyboardEvent<HTMLElement>) => {
    if (event.key === "Escape") {
      setSelectedComputer(null);
      layerRef.current?.select(null);
    }
  };

  const onStackChange = (next: string) => {
    if (remoteHostForStack(next)) {
      setPendingStack(next);
      return;
    }
    setStackId(next);
    setPendingStack(null);
  };

  const confirmRemote = () => {
    if (pendingStack) {
      setStackId(pendingStack);
      setPendingStack(null);
    }
  };

  if (loadError) {
    return (
      <div className={styles.fallbackWrap}>
        <div className={styles.fallback} role="alert">
          Globe unavailable: {loadError} — showing COMPUTERS roster.
        </div>
        <ComputersPanelContent />
      </div>
    );
  }

  const nodeRow = (row: NodeRow) => (
    <li key={row.id}>
      <button
        type="button"
        className={`${styles.nodeRow}${selectedComputerId === row.id ? ` ${styles.nodeRowSelected}` : ""}`}
        onClick={() => focusNode(row)}
      >
        {row.name}
      </button>
    </li>
  );

  return (
    <div className={styles.root} data-testid="godseye-root">
      <div className={styles.canvasWrap}>
        <div ref={canvasRef} className={styles.canvas} data-testid="godseye-canvas" />
        {!ready && <div className={styles.loading}>initialising globe…</div>}
        <div ref={creditRef} className={styles.creditsHost} data-testid="godseye-credits" aria-live="polite" />
      </div>
      <aside className={styles.rail} onKeyDown={onRailKeyDown} data-testid="godseye-rail">
        <div data-testid="godseye-counts">
          nodes <strong>{placed.length}</strong> placed · <strong>{unplaced.length}</strong> unplaced ·{" "}
          <strong>{arcCount}</strong> arcs
        </div>
        <label htmlFor="godseye-stack">STACK</label>
        <select
          id="godseye-stack"
          className={styles.stackSelect}
          value={stackId}
          onChange={(e) => onStackChange(e.target.value)}
        >
          <option value="naturalearth">NaturalEarth · offline</option>
          <option value="esri-imagery">Esri SAT</option>
          <option value="osm">OSM</option>
        </select>
        {pendingStack && (
          <div className={styles.remoteWarn}>
            sends tile requests to {remoteHostForStack(pendingStack)}
            <button type="button" className={styles.nodeRow} onClick={confirmRemote}>
              confirm switch
            </button>
          </div>
        )}
        <div className={styles.listTitle}>PLACED</div>
        <ul className={styles.list} data-testid="godseye-placed">
          {placed.map(nodeRow)}
        </ul>
        <div className={styles.listTitle}>UNPLACED</div>
        <ul className={styles.list} data-testid="godseye-unplaced">
          {unplaced.map(nodeRow)}
        </ul>
        <p className={styles.hint}>set geo or COCKPIT_NODE_GEO</p>
      </aside>
    </div>
  );
}
