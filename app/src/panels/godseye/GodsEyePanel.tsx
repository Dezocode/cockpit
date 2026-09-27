import { useCallback, useEffect, useRef, useState } from "react";
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
import { createFleetNodesLayer } from "./layers/fleetNodes.js";
import { ESRI_TILE_HOST, OSM_TILE_HOST } from "./gev/maps/imagery.js";
import { observeGodsEyeTheme, readGodsEyeThemeColors } from "./theme.js";
import { useCockpitStore } from "../../stores/cockpit.js";

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

let liveViewerCount = 0;

async function applyMapStack(
  viewer: Cesium.Viewer,
  stackId: string,
  credits: ReturnType<typeof createMapCredits>,
) {
  const gl = (viewer.scene as unknown as { context?: { gl?: WebGLRenderingContext } }).context?.gl;
  const swiftShader = gl ? /SwiftShader/i.test(String(gl.getParameter(gl.RENDERER))) : false;
  if (swiftShader) {
    viewer.imageryLayers.removeAll();
    viewer.scene.globe.show = false;
    if (viewer.scene.skyAtmosphere) viewer.scene.skyAtmosphere.show = false;
    viewer.terrainProvider = new Cesium.EllipsoidTerrainProvider();
    credits.show("Natural Earth II (public domain, bundled with Cesium)");
    governorRequestRender("map-stack-swiftshader");
    return;
  }
  const config = createDefaultMapSources();
  const resolved = resolveStackId(config, stackId);
  const entry = findMapSource(config, resolved) as NonNullable<
    ReturnType<typeof createDefaultMapSources>["sources"][number]
  >;
  if (!entry) throw new Error(`unknown stack ${stackId}`);
  let imageryProvider = entry.imagery() as Cesium.ImageryProvider | Promise<Cesium.ImageryProvider>;
  if (typeof (imageryProvider as Promise<Cesium.ImageryProvider>).then === "function") {
    imageryProvider = await imageryProvider;
  }
  viewer.imageryLayers.removeAll();
  viewer.imageryLayers.addImageryProvider(imageryProvider as Cesium.ImageryProvider);
  const terrainBundle = await entry.terrain.create({});
  viewer.terrainProvider = terrainBundle.provider as Cesium.TerrainProvider;
  credits.show(typeof entry.credit === "string" ? entry.credit : null);
  governorRequestRender("map-stack");
}

export default function GodsEyePanel() {
  const canvasRef = useRef<HTMLDivElement>(null);
  const creditRef = useRef<HTMLDivElement>(null);
  const viewerRef = useRef<Cesium.Viewer | null>(null);
  const layerRef = useRef<ReturnType<typeof createFleetNodesLayer> | null>(null);
  const creditsRef = useRef<ReturnType<typeof createMapCredits> | null>(null);
  const disposePinchRef = useRef<(() => void) | null>(null);
  const pollRef = useRef<number | null>(null);
  const [stackId, setStackId] = useState("naturalearth");
  const [pendingStack, setPendingStack] = useState<string | null>(null);
  const [ready, setReady] = useState(false);
  const [unplaced, setUnplaced] = useState<Array<{ id: string; name: string }>>([]);
  const [entityCount, setEntityCount] = useState(0);
  const [loadError, setLoadError] = useState<string | null>(null);
  const setSelectedComputer = useCockpitStore((s) => s.setSelectedComputer);
  const selectedComputerId = useCockpitStore((s) => s.selectedComputerId);

  const publishDiagnostics = useCallback(
    (diag?: { placed: number; unplaced: number }) => {
      window.__cockpitGodsEye = {
        ready,
        entityCount: diag?.placed ?? entityCount,
        liveViewers: liveViewerCount,
        unplaced: diag?.unplaced ?? unplaced.length,
      };
    },
    [ready, entityCount, unplaced.length],
  );

  useEffect(() => {
    publishDiagnostics();
  }, [publishDiagnostics]);

  useEffect(() => {
    const canvasHost = canvasRef.current;
    const creditHost = creditRef.current;
    if (!canvasHost || !creditHost) return;
    let cancelled = false;
    liveViewerCount += 1;

    (async () => {
      try {
        await new Promise<void>((resolve) => {
          requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
        });
        const rect = canvasHost.getBoundingClientRect();
        if (rect.width < 2 || rect.height < 2) {
          throw new Error("globe canvas has no layout dimensions");
        }
        canvasHost.style.width = "640px";
        canvasHost.style.height = "480px";
        const viewer = createApplicationViewer({
          container: canvasHost,
          creditContainer: creditHost,
        });
        if (cancelled) {
          viewer.destroy();
          liveViewerCount -= 1;
          return;
        }
        viewerRef.current = viewer;
        viewer.resize();
        disposePinchRef.current = installTrackpadPinchZoom(viewer);
        installRenderGovernor(viewer);
        const colors = readGodsEyeThemeColors();
        const gl = (viewer.scene as unknown as { context?: { gl?: WebGLRenderingContext } }).context?.gl;
        const renderer = gl ? String(gl.getParameter(gl.RENDERER)) : "";
        if (/SwiftShader/i.test(renderer)) {
          viewer.scene.globe.show = false;
          if (viewer.scene.skyAtmosphere) viewer.scene.skyAtmosphere.show = false;
        }
        viewer.scene.backgroundColor = Cesium.Color.fromCssColorString(colors.bg || "black");

        const credits = createMapCredits(viewer);
        creditsRef.current = credits;
        await applyMapStack(viewer, stackId, credits);

        const layer = createFleetNodesLayer({
          source: createFleetSnapshotSource(),
          host: {
            onSelectComputer: (id) => setSelectedComputer(id),
            readThemeColors: () => {
              const t = readGodsEyeThemeColors();
              return { accent: t.accent, active: t.active, text: t.text };
            },
            tzCentroids: {},
            localTz: Intl.DateTimeFormat().resolvedOptions().timeZone,
            nodeGeoEnv: "",
          },
        });
        layerRef.current = layer;
        layer.init(viewer);
        layer.enable();
        await layer.update();
        const diag = layer.getDiagnostics();
        setEntityCount(diag.placed);
        setUnplaced(diag.unplacedRows);
        setReady(true);
        publishDiagnostics({ placed: diag.placed, unplaced: diag.unplaced });
        pollRef.current = window.setInterval(() => {
          void layer.update().then(() => {
            const d = layer.getDiagnostics();
            setEntityCount(d.placed);
            setUnplaced(d.unplacedRows);
            publishDiagnostics({ placed: d.placed, unplaced: d.unplaced });
          });
        }, 5000);
      } catch (error) {
        setLoadError(error instanceof Error ? error.message : String(error));
        liveViewerCount = Math.max(0, liveViewerCount - 1);
      }
    })();

    return () => {
      cancelled = true;
      if (pollRef.current) window.clearInterval(pollRef.current);
      pollRef.current = null;
      layerRef.current?.destroy();
      layerRef.current = null;
      creditsRef.current?.destroy();
      creditsRef.current = null;
      disposePinchRef.current?.();
      disposePinchRef.current = null;
      if (viewerRef.current) {
        uninstallRenderGovernor(viewerRef.current);
        viewerRef.current.destroy();
        viewerRef.current = null;
      }
      liveViewerCount = Math.max(0, liveViewerCount - 1);
      setReady(false);
      window.__cockpitGodsEye = {
        ready: false,
        entityCount: 0,
        liveViewers: liveViewerCount,
        unplaced: 0,
      };
    };
  }, [publishDiagnostics, setSelectedComputer]);

  useEffect(() => {
    const viewer = viewerRef.current;
    const credits = creditsRef.current;
    if (!viewer || !credits || !ready) return;
    void applyMapStack(viewer, stackId, credits).catch((error) => {
      setLoadError(error instanceof Error ? error.message : String(error));
    });
  }, [stackId, ready]);

  useEffect(() => {
    const stop = observeGodsEyeTheme(() => {
      const viewer = viewerRef.current;
      const colors = readGodsEyeThemeColors();
      if (viewer) {
        viewer.scene.backgroundColor = Cesium.Color.fromCssColorString(colors.bg || "black");
      }
      layerRef.current?.getDiagnostics().applyThemeColors?.();
      governorRequestRender("theme");
    });
    return stop;
  }, []);

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
    return <div className={styles.fallback}>Globe unavailable: {loadError}</div>;
  }

  return (
    <div className={styles.root} data-testid="godseye-root">
      <div className={styles.canvasWrap}>
        {!ready && <div className={styles.loading}>initialising globe…</div>}
        <div ref={canvasRef} className={styles.canvas} data-testid="godseye-canvas" />
        <div ref={creditRef} className={styles.creditsHost} aria-live="polite" />
      </div>
      <aside className={styles.rail}>
        <div>
          nodes <strong>{entityCount}</strong> placed · {unplaced.length} unplaced
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
            sends tile requests to {pendingStack ? remoteHostForStack(pendingStack) : ""}
            <button type="button" className={styles.nodeRow} onClick={confirmRemote}>
              confirm switch
            </button>
          </div>
        )}
        <div className={styles.unplacedTitle}>UNPLACED</div>
        <ul>
          {unplaced.map((row) => (
            <li key={row.id}>
              <button
                type="button"
                className={`${styles.nodeRow}${selectedComputerId === row.id ? ` ${styles.nodeRowSelected}` : ""}`}
                onClick={() => setSelectedComputer(row.id)}
              >
                {row.name}
              </button>
            </li>
          ))}
        </ul>
        <p className={styles.hint}>set geo or COCKPIT_NODE_GEO</p>
      </aside>
    </div>
  );
}
