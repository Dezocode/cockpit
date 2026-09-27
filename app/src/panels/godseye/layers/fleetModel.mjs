// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/layers/earthquakes/model.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: fleet roster mapping (layer contract only).

function parseNodeGeo(raw) {
  if (!raw) return null;
  const text = String(raw).trim();
  const m = text.match(/^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$/);
  if (!m) return null;
  const lat = Number(m[1]);
  const lon = Number(m[2]);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  return { lat, lon };
}

export function assertComputersPayload(payload) {
  if (!payload || typeof payload !== 'object') throw new TypeError('computers payload required');
  if (!Array.isArray(payload.computers)) throw new TypeError('computers[] required');
  if (typeof payload.offlineThresholdMs !== 'number') {
    throw new TypeError('offlineThresholdMs required');
  }
  return payload;
}

/**
 * @param {object} params
 * @param {import('./fleetModel.d.mts').ComputersPayload} params.payload
 * @param {Record<string, {lat:number, lon:number}>} [params.tzCentroids]
 * @param {string} [params.localTz]
 * @param {string} [params.nodeGeoEnv]
 */
export function mapFleetRoster({
  payload,
  tzCentroids = {},
  localTz = 'UTC',
  nodeGeoEnv = '',
}) {
  assertComputersPayload(payload);
  const threshold = payload.offlineThresholdMs;
  const placed = [];
  const unplaced = [];
  for (const row of payload.computers) {
    if (!row?.id || !row.name) throw new TypeError('malformed computer row');
    const online =
      row.status === 'online' ||
      (typeof row.latencyMs === 'number' && row.latencyMs <= threshold);
    const colorToken = online ? 'accent' : 'active';
    let geo = row.geo ?? null;
    let geoSource = row.geoSource ?? null;
    if (!geo && row.id === 'local') {
      geo = parseNodeGeo(nodeGeoEnv);
      if (geo) geoSource = 'env';
      if (!geo && localTz && tzCentroids[localTz]) {
        geo = tzCentroids[localTz];
        geoSource = 'tz';
      }
    }
    if (geo && Number.isFinite(geo.lat) && Number.isFinite(geo.lon)) {
      placed.push({
        id: row.id,
        name: row.name,
        latencyMs: row.latencyMs ?? 0,
        online,
        colorToken,
        geo,
        geoSource: geoSource ?? 'explicit',
      });
    } else {
      unplaced.push({ id: row.id, name: row.name, latencyMs: row.latencyMs ?? 0, online });
    }
  }
  const local = placed.find((n) => n.id === 'local') ?? null;
  return { placed, unplaced, local, offlineThresholdMs: threshold };
}

/**
 * Arcs run from the local node to every other placed node, labelled with the
 * node's latency. Pure (no cesium) so the arc path is node-testable even when
 * the live roster has a single placed node and therefore draws no arc.
 * @param {{ placed: import('./fleetModel.d.mts').PlacedNode[], local: import('./fleetModel.d.mts').PlacedNode | null }} mapped
 */
export function computeFleetArcs({ placed, local }) {
  if (!local) return [];
  const arcs = [];
  for (const node of placed) {
    if (node.id === local.id) continue;
    arcs.push({
      id: `${local.id}->${node.id}`,
      fromId: local.id,
      toId: node.id,
      from: local.geo,
      to: node.geo,
      midpoint: geodesicMidpoint(local.geo, node.geo),
      latencyMs: node.latencyMs,
      label: `${node.latencyMs} ms`,
      colorToken: node.colorToken,
    });
  }
  return arcs;
}

/** Great-circle midpoint of two {lat, lon} points in degrees. */
export function geodesicMidpoint(a, b) {
  const rad = Math.PI / 180;
  const lat1 = a.lat * rad;
  const lat2 = b.lat * rad;
  const dLon = (b.lon - a.lon) * rad;
  const bx = Math.cos(lat2) * Math.cos(dLon);
  const by = Math.cos(lat2) * Math.sin(dLon);
  const lat = Math.atan2(
    Math.sin(lat1) + Math.sin(lat2),
    Math.sqrt((Math.cos(lat1) + bx) ** 2 + by ** 2),
  );
  const lon = a.lon * rad + Math.atan2(by, Math.cos(lat1) + bx);
  let lonDeg = lon / rad;
  if (lonDeg > 180) lonDeg -= 360;
  if (lonDeg < -180) lonDeg += 360;
  return { lat: lat / rad, lon: lonDeg };
}

/**
 * Clamp a requested polyline width into the GL-supported aliased line width
 * range (gl.ALIASED_LINE_WIDTH_RANGE). ANGLE/SwiftShader (headless CI) and
 * most desktop ANGLE builds report [1, 1]; an unknown or malformed range
 * falls back to width 1 so arcs always draw.
 * @param {number} requested
 * @param {ArrayLike<number> | null | undefined} range
 */
export function clampLineWidth(requested, range) {
  const want = Number.isFinite(requested) && requested > 0 ? requested : 1;
  const min = Number(range?.[0]);
  const max = Number(range?.[1]);
  if (!Number.isFinite(min) || !Number.isFinite(max) || max < 1 || min > max) return 1;
  return Math.min(Math.max(want, Math.max(1, min)), max);
}
