#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const tabPath =
  process.argv[2] || '/usr/share/zoneinfo/zone1970.tab';
const outPath = join(__dirname, 'tz-centroids.json');

function parseZone1970Coord(token) {
  const m = String(token).match(/^([+-])(\d{2})(\d{2})([+-])(\d{3})(\d{2})$/);
  if (!m) return null;
  const latSign = m[1] === '-' ? -1 : 1;
  const lonSign = m[4] === '-' ? -1 : 1;
  const lat = latSign * (Number(m[2]) + Number(m[3]) / 60);
  const lon = lonSign * (Number(m[5]) + Number(m[6]) / 60);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  return { lat, lon };
}

const text = readFileSync(tabPath, 'utf8');
const centroids = {};
for (const line of text.split('\n')) {
  if (!line || line.startsWith('#')) continue;
  const parts = line.split('\t');
  if (parts.length < 3) continue;
  const geo = parseZone1970Coord(parts[1]);
  const tz = parts[2];
  if (!geo || !tz) continue;
  if (!centroids[tz]) centroids[tz] = geo;
}

writeFileSync(outPath, `${JSON.stringify(centroids, null, 2)}\n`);
console.log(`tz-centroids: wrote ${Object.keys(centroids).length} zones -> ${outPath}`);
