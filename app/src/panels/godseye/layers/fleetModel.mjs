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
