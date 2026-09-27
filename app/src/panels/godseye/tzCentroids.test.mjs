import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { parseZone1970Coord, parseZone1970Tab } from "../../../server/fleet/gen-tz-centroids.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const table = JSON.parse(readFileSync(join(here, "../../../server/fleet/tz-centroids.json"), "utf8"));

test("zone1970 coords parse in both DDMM and DDMMSS forms", () => {
  assert.deepEqual(parseZone1970Coord("+4230+00131"), { lat: 42.5, lon: 1 + 31 / 60 });
  const chicago = parseZone1970Coord("+415100-0873900");
  assert.ok(Math.abs(chicago.lat - 41.85) < 1e-9);
  assert.ok(Math.abs(chicago.lon + 87.65) < 1e-9);
  assert.equal(parseZone1970Coord("+4151-0873900"), null); // mixed precision
  assert.equal(parseZone1970Coord("garbage"), null);
});

test("parser refuses to silently drop rows", () => {
  assert.throws(() => parseZone1970Tab("US\t+41-087\tAmerica/Nowhere\n"), /unparsed row/);
  const parsed = parseZone1970Tab("# c\nUS\t+415100-0873900\tAmerica/Chicago\tCentral\n");
  assert.deepEqual(Object.keys(parsed), ["America/Chicago"]);
});

test("committed tz-centroids.json covers seconds-precision zones; no invented UTC point", () => {
  for (const tz of ["America/Chicago", "America/New_York", "America/Los_Angeles", "Europe/London", "Asia/Tokyo"]) {
    assert.ok(table[tz], `${tz} present`);
  }
  assert.equal(table.UTC, undefined);
  assert.equal(table["Etc/UTC"], undefined);
});
