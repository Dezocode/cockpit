#!/usr/bin/env node
// Generates tz-centroids.json (IANA zone -> principal-location lat/lon) from
// tzdata zone1970.tab (public domain). Run once; the JSON is committed.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * zone1970.tab coordinates are ISO 6709 in either ±DDMM±DDDMM or
 * ±DDMMSS±DDDMMSS form (e.g. America/Chicago is +415100-0873900).
 */
export function parseZone1970Coord(token) {
  const m = String(token).match(
    /^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/,
  );
  if (!m) return null;
  // Both halves must use the same precision.
  if ((m[4] === undefined) !== (m[8] === undefined)) return null;
  const latSign = m[1] === '-' ? -1 : 1;
  const lonSign = m[5] === '-' ? -1 : 1;
  const lat = latSign * (Number(m[2]) + Number(m[3]) / 60 + Number(m[4] ?? 0) / 3600);
  const lon = lonSign * (Number(m[6]) + Number(m[7]) / 60 + Number(m[8] ?? 0) / 3600);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  if (Math.abs(lat) > 90 || Math.abs(lon) > 180) return null;
  return { lat, lon };
}

export function parseZone1970Tab(text) {
  const centroids = {};
  for (const line of text.split('\n')) {
    if (!line || line.startsWith('#')) continue;
    const parts = line.split('\t');
    if (parts.length < 3) continue;
    const geo = parseZone1970Coord(parts[1]);
    const tz = parts[2];
    if (!geo || !tz) throw new Error(`zone1970.tab: unparsed row: ${line}`);
    if (!centroids[tz]) centroids[tz] = geo;
  }
  return centroids;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const tabPath = process.argv[2] || '/usr/share/zoneinfo/zone1970.tab';
  const outPath = join(__dirname, 'tz-centroids.json');
  const centroids = parseZone1970Tab(readFileSync(tabPath, 'utf8'));
  writeFileSync(outPath, `${JSON.stringify(centroids, null, 2)}\n`);
  console.log(`tz-centroids: wrote ${Object.keys(centroids).length} zones -> ${outPath}`);
}
