import { test } from "node:test";
import assert from "node:assert/strict";
import {
  mapFleetRoster,
  assertComputersPayload,
  computeFleetArcs,
  geodesicMidpoint,
  clampLineWidth,
} from "./layers/fleetModel.mjs";

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

test("arcs run local -> every other placed node, labelled with latency", () => {
  const payload = {
    computers: [
      { id: "local", name: "Local", status: "online", latencyMs: 0, geo: { lat: 10, lon: 20 } },
      { id: "a", name: "A", status: "online", latencyMs: 12, geo: { lat: -10, lon: 40 } },
      { id: "b", name: "B", status: "offline", latencyMs: 9000, geo: { lat: 50, lon: -100 } },
      { id: "c", name: "C", status: "online", latencyMs: 7 },
    ],
    offlineThresholdMs: 3000,
  };
  const mapped = mapFleetRoster({ payload });
  const arcs = computeFleetArcs(mapped);
  assert.deepEqual(arcs.map((a) => a.id), ["local->a", "local->b"]);
  assert.equal(arcs[0].label, "12 ms");
  assert.equal(arcs[0].colorToken, "accent");
  assert.equal(arcs[1].colorToken, "active");
  assert.deepEqual(arcs[0].from, { lat: 10, lon: 20 });
  assert.deepEqual(arcs[0].to, { lat: -10, lon: 40 });
});

test("no arcs without a placed local node, and none for a lone local node", () => {
  const lone = mapFleetRoster({
    payload: {
      computers: [
        { id: "local", name: "Local", status: "online", latencyMs: 0, geo: { lat: 1, lon: 2 } },
        { id: "x", name: "X", status: "online", latencyMs: 5 },
      ],
      offlineThresholdMs: 3000,
    },
  });
  assert.equal(computeFleetArcs(lone).length, 0);
  const noLocal = mapFleetRoster({
    payload: {
      computers: [{ id: "a", name: "A", status: "online", latencyMs: 1, geo: { lat: 1, lon: 2 } }],
      offlineThresholdMs: 3000,
    },
  });
  assert.equal(noLocal.local, null);
  assert.equal(computeFleetArcs(noLocal).length, 0);
});

test("geodesic midpoint", () => {
  const m = geodesicMidpoint({ lat: 0, lon: 0 }, { lat: 0, lon: 90 });
  assert.ok(Math.abs(m.lat) < 1e-9);
  assert.ok(Math.abs(m.lon - 45) < 1e-9);
  const w = geodesicMidpoint({ lat: 0, lon: 170 }, { lat: 0, lon: -170 });
  assert.ok(Math.abs(Math.abs(w.lon) - 180) < 1e-9);
});

test("line width clamps into the GL aliased line width range", () => {
  assert.equal(clampLineWidth(2, [1, 1]), 1); // ANGLE / SwiftShader headless
  assert.equal(clampLineWidth(2, new Float32Array([1, 8])), 2);
  assert.equal(clampLineWidth(12, [1, 8]), 8);
  assert.equal(clampLineWidth(0.5, [1, 8]), 1);
  assert.equal(clampLineWidth(2, null), 1);
  assert.equal(clampLineWidth(2, [0, 0]), 1);
  assert.equal(clampLineWidth(Number.NaN, [1, 4]), 1);
});
