import { test } from "node:test";
import assert from "node:assert/strict";
import { mapFleetRoster, assertComputersPayload } from "./layers/fleetModel.mjs";

test("placement ladder explicit > env > tz > unplaced", () => {
  const payload = {
    computers: [
      { id: "local", name: "Local", status: "online", latencyMs: 0, geo: { lat: 1, lon: 2 }, geoSource: "explicit" },
      { id: "hermes", name: "Hermes", status: "online", latencyMs: 3 },
    ],
    offlineThresholdMs: 3000,
  };
  const mapped = mapFleetRoster({ payload, nodeGeoEnv: "9,10", tzCentroids: { UTC: { lat: 0, lon: 0 } }, localTz: "UTC" });
  assert.equal(mapped.placed.length, 1);
  assert.equal(mapped.placed[0].geo.lat, 1);
  assert.equal(mapped.unplaced.length, 1);
  assert.equal(mapped.placed[0].colorToken, "accent");
});

test("offline uses active color token", () => {
  const payload = {
    computers: [{ id: "local", name: "Local", status: "offline", latencyMs: 9000, geo: { lat: 1, lon: 2 } }],
    offlineThresholdMs: 3000,
  };
  const mapped = mapFleetRoster({ payload });
  assert.equal(mapped.placed[0].colorToken, "active");
});

test("malformed payload rejected", () => {
  assert.throws(() => assertComputersPayload({ computers: [] }), /offlineThresholdMs/);
});
