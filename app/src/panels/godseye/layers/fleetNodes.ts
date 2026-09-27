// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/layers/earthquakes/index.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: fleet nodes layer (layer contract only).
import * as Cesium from 'cesium';
import { mapFleetRoster, computeFleetArcs, clampLineWidth } from './fleetModel.mjs';
import { governorRequestRender } from '../gev/renderGovernor.js';
import type { ComputersPayload, FleetArc, PlacedNode } from './fleetModel.d.mts';

export type FleetLayerHost = {
  onSelectComputer?: (id: string) => void;
  readThemeColors: () => { accent: string; active: string; text: string };
  tzCentroids: Record<string, { lat: number; lon: number }>;
  localTz: string;
  nodeGeoEnv: string;
};

/** Nodes and arcs float slightly above the ellipsoid so the globe never occludes them. */
const NODE_ALTITUDE_M = 20_000;
const ARC_REQUESTED_WIDTH = 2;
const ARC_LABEL_PREFIX = 'arc-label:';

/** Theme tokens → Cesium colors; an empty token yields undefined (Cesium default), never a literal. */
function tokenColor(css: string): Cesium.Color | undefined {
  const trimmed = css.trim();
  return trimmed ? Cesium.Color.fromCssColorString(trimmed) : undefined;
}

/** gl.ALIASED_LINE_WIDTH_RANGE of the viewer's context, or null when unreadable. */
function aliasedLineWidthRange(viewer: Cesium.Viewer): ArrayLike<number> | null {
  try {
    // getContext() with the viewer's own context type returns that existing context.
    const canvas = viewer.scene.canvas;
    const gl = canvas.getContext('webgl2') ?? canvas.getContext('webgl');
    return gl ? (gl.getParameter(gl.ALIASED_LINE_WIDTH_RANGE) as ArrayLike<number>) : null;
  } catch {
    return null;
  }
}

export function createFleetNodesLayer({
  source,
  host,
}: {
  source: { getSnapshot: (opts: { signal?: AbortSignal }) => Promise<unknown> };
  host: FleetLayerHost;
}) {
  if (typeof source?.getSnapshot !== 'function') {
    throw new TypeError('Fleet layer requires a snapshot source');
  }
  let _viewer: Cesium.Viewer | null = null;
  let _dataSource: Cesium.CustomDataSource | null = null;
  let _request: AbortController | null = null;
  let _enabled = false;
  let _placed: PlacedNode[] = [];
  let _arcs: FleetArc[] = [];
  let _unplaced: Array<{ id: string; name: string }> = [];
  let _selectedId: string | null = null;
  let _handler: Cesium.ScreenSpaceEventHandler | null = null;
  let _arcWidth = 1;

  function colorFor(token: 'accent' | 'active', colors: { accent: string; active: string }) {
    return tokenColor(token === 'accent' ? colors.accent : colors.active);
  }

  function applyColors() {
    if (!_dataSource) return;
    const colors = host.readThemeColors();
    const textColor = tokenColor(colors.text);
    for (const node of _placed) {
      const entity = _dataSource.entities.getById(node.id);
      if (!entity) continue;
      if (entity.point) entity.point.color = new Cesium.ConstantProperty(colorFor(node.colorToken, colors));
      if (entity.label) entity.label.fillColor = new Cesium.ConstantProperty(textColor);
    }
    for (const arc of _arcs) {
      const line = _dataSource.entities.getById(arc.id);
      if (line?.polyline) {
        line.polyline.material = new Cesium.ColorMaterialProperty(colorFor(arc.colorToken, colors));
      }
      const label = _dataSource.entities.getById(`${ARC_LABEL_PREFIX}${arc.id}`);
      if (label?.label) label.label.fillColor = new Cesium.ConstantProperty(textColor);
    }
    governorRequestRender('fleet-theme');
  }

  function rebuildEntities(placed: PlacedNode[], arcs: FleetArc[]) {
    if (!_dataSource) return;
    _dataSource.entities.removeAll();
    const colors = host.readThemeColors();
    const textColor = tokenColor(colors.text);
    for (const arc of arcs) {
      _dataSource.entities.add({
        id: arc.id,
        polyline: {
          positions: Cesium.Cartesian3.fromDegreesArrayHeights([
            arc.from.lon, arc.from.lat, NODE_ALTITUDE_M,
            arc.to.lon, arc.to.lat, NODE_ALTITUDE_M,
          ]),
          arcType: Cesium.ArcType.GEODESIC,
          width: _arcWidth,
          material: new Cesium.ColorMaterialProperty(colorFor(arc.colorToken, colors)),
        },
      });
      _dataSource.entities.add({
        id: `${ARC_LABEL_PREFIX}${arc.id}`,
        position: Cesium.Cartesian3.fromDegrees(arc.midpoint.lon, arc.midpoint.lat, NODE_ALTITUDE_M),
        label: {
          text: arc.label,
          font: '10px monospace',
          fillColor: new Cesium.ConstantProperty(textColor),
          style: Cesium.LabelStyle.FILL,
          showBackground: true,
        },
      });
    }
    for (const node of placed) {
      _dataSource.entities.add({
        id: node.id,
        position: Cesium.Cartesian3.fromDegrees(node.geo.lon, node.geo.lat, NODE_ALTITUDE_M),
        point: {
          pixelSize: 10,
          color: new Cesium.ConstantProperty(colorFor(node.colorToken, colors)),
          outlineWidth: 0,
        },
        label: {
          text: node.name,
          font: '11px monospace',
          fillColor: new Cesium.ConstantProperty(textColor),
          style: Cesium.LabelStyle.FILL,
          showBackground: true,
          verticalOrigin: Cesium.VerticalOrigin.BOTTOM,
          pixelOffset: new Cesium.Cartesian2(0, -12),
        },
      });
    }
    governorRequestRender('fleet');
  }

  const layer = {
    id: 'fleet',
    name: 'Fleet nodes',
    icon: '🛰',
    source: 'cockpit:/api/computers',
    updateInterval: 5000,

    init(viewer: Cesium.Viewer) {
      if (_viewer) throw new Error('Fleet layer already initialized');
      _viewer = viewer;
      _arcWidth = clampLineWidth(ARC_REQUESTED_WIDTH, aliasedLineWidthRange(viewer));
      _dataSource = new Cesium.CustomDataSource('fleet-nodes');
      void viewer.dataSources.add(_dataSource);
      _handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas);
      _handler.setInputAction((movement: { position: Cesium.Cartesian2 }) => {
        const picked = viewer.scene.pick(movement.position);
        const id = picked?.id?.id;
        if (typeof id === 'string' && _placed.some((p) => p.id === id)) {
          _selectedId = id;
          host.onSelectComputer?.(id);
          governorRequestRender('fleet-select');
        }
      }, Cesium.ScreenSpaceEventType.LEFT_CLICK);
    },

    enable() {
      _enabled = true;
      if (_dataSource) _dataSource.show = true;
    },

    disable() {
      _request?.abort();
      _request = null;
      _enabled = false;
      if (_dataSource) _dataSource.show = false;
    },

    async update() {
      if (!_enabled || !_viewer || !_dataSource) return false;
      _request?.abort();
      const request = new AbortController();
      _request = request;
      try {
        const payload = await source.getSnapshot({ signal: request.signal });
        if (request.signal.aborted || _request !== request || !_enabled) return false;
        const mapped = mapFleetRoster({
          payload: payload as ComputersPayload,
          tzCentroids: host.tzCentroids,
          localTz: host.localTz,
          nodeGeoEnv: host.nodeGeoEnv,
        });
        const arcs = computeFleetArcs(mapped);
        _placed = mapped.placed;
        _unplaced = mapped.unplaced;
        _arcs = arcs;
        rebuildEntities(mapped.placed, arcs);
        return true;
      } catch (error) {
        if (request.signal.aborted) return false;
        throw error;
      }
    },

    /** Select a placed node (keyboard / rail) without a pick. */
    select(id: string | null) {
      _selectedId = id;
      governorRequestRender('fleet-select');
    },

    destroy() {
      _request?.abort();
      _request = null;
      _handler?.destroy();
      _handler = null;
      if (_viewer && _dataSource) {
        _viewer.dataSources.remove(_dataSource, true);
      }
      _dataSource = null;
      _viewer = null;
      _enabled = false;
      _placed = [];
      _arcs = [];
      _unplaced = [];
    },

    getDiagnostics() {
      return {
        placed: _placed.length,
        unplaced: _unplaced.length,
        arcs: _arcs.length,
        arcWidth: _arcWidth,
        selectedId: _selectedId,
        applyThemeColors: applyColors,
        unplacedRows: _unplaced,
        placedRows: _placed,
      };
    },
  };

  return layer;
}

export type FleetNodesLayer = ReturnType<typeof createFleetNodesLayer>;
