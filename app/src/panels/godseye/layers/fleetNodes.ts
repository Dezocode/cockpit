// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/layers/earthquakes/index.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: fleet nodes layer (layer contract only).
import * as Cesium from 'cesium';
import { mapFleetRoster } from './fleetModel.mjs';
import { governorRequestRender } from '../gev/renderGovernor.js';
import type { PlacedNode } from './fleetModel.d.mts';

export type FleetLayerHost = {
  onSelectComputer?: (id: string) => void;
  readThemeColors: () => { accent: string; active: string; text: string };
  tzCentroids: Record<string, { lat: number; lon: number }>;
  localTz: string;
  nodeGeoEnv: string;
};

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
  let _unplaced: Array<{ id: string; name: string }> = [];
  let _selectedId: string | null = null;
  let _handler: Cesium.ScreenSpaceEventHandler | null = null;

  function applyColors() {
    if (!_dataSource) return;
    const colors = host.readThemeColors();
    for (const entity of _dataSource.entities.values) {
      const placed = _placed.find((p) => p.id === entity.id);
      if (!placed) continue;
      const css = placed.colorToken === 'accent' ? colors.accent : colors.active;
      const c = Cesium.Color.fromCssColorString(css.trim() || 'white');
      if (entity.point) entity.point.color = new Cesium.ConstantProperty(c);
      if (entity.label) {
        entity.label.fillColor = new Cesium.ConstantProperty(
          Cesium.Color.fromCssColorString(colors.text.trim() || 'white'),
        );
      }
      if (entity.polyline) entity.polyline.material = new Cesium.ColorMaterialProperty(c);
    }
    governorRequestRender('fleet-theme');
  }

  function rebuildEntities(_viewer: Cesium.Viewer, placed: PlacedNode[], _local: PlacedNode | null) {
    if (!_dataSource) return;
    _dataSource.entities.removeAll();
    const colors = host.readThemeColors();
    for (const node of placed) {
      const css = node.colorToken === 'accent' ? colors.accent : colors.active;
      const color = Cesium.Color.fromCssColorString(css.trim() || 'white');
      const textColor = Cesium.Color.fromCssColorString(colors.text.trim() || 'white');
      _dataSource.entities.add({
        id: node.id,
        position: Cesium.Cartesian3.fromDegrees(node.geo.lon, node.geo.lat),
        point: {
          pixelSize: 10,
          color: new Cesium.ConstantProperty(color),
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
      _dataSource = new Cesium.CustomDataSource('fleet-nodes');
      viewer.dataSources.add(_dataSource);
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
          payload: payload as import('./fleetModel.d.mts').ComputersPayload,
          tzCentroids: host.tzCentroids,
          localTz: host.localTz,
          nodeGeoEnv: host.nodeGeoEnv,
        });
        _placed = mapped.placed;
        _unplaced = mapped.unplaced;
        rebuildEntities(_viewer, mapped.placed, mapped.local);
        return true;
      } catch (error) {
        if (request.signal.aborted) return false;
        throw error;
      }
    },

    destroy() {
      _request?.abort();
      _handler?.destroy();
      _handler = null;
      if (_viewer && _dataSource) {
        _viewer.dataSources.remove(_dataSource, true);
      }
      _dataSource = null;
      _viewer = null;
      _enabled = false;
      _placed = [];
      _unplaced = [];
    },

    getDiagnostics() {
      return {
        placed: _placed.length,
        unplaced: _unplaced.length,
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
