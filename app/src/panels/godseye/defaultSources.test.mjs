import { test } from "node:test";
import assert from "node:assert/strict";
import { createDefaultMapSources, resolveStackId } from "./gev/maps/defaultSources.js";

test("default stack is naturalearth (keyless)", () => {
  const config = createDefaultMapSources({
    imageryFactories: {
      naturalearth: () => ({ id: "ne" }),
      osm: () => ({ id: "osm" }),
      esri: () => ({ id: "esri" }),
    },
    terrainFactories: {
      flat: async () => ({ provider: { id: "flat" } }),
      keyless: async () => ({ provider: { id: "keyless" } }),
    },
  });
  assert.equal(config.defaultId, "naturalearth");
  assert.equal(resolveStackId(config, "missing"), "naturalearth");
});

test("esri construction failure falls back to osm entry", () => {
  let esriCalls = 0;
  const config = createDefaultMapSources({
    imageryFactories: {
      naturalearth: () => ({ id: "ne" }),
      osm: () => ({ id: "osm" }),
      esri: () => {
        esriCalls += 1;
        if (esriCalls === 1) throw new Error("fail");
        return { id: "osm" };
      },
    },
    terrainFactories: {
      flat: async () => ({ provider: {} }),
      keyless: async () => ({ provider: {} }),
    },
  });
  const esri = config.sources.find((s) => s.descriptor.id === "esri-imagery");
  assert.ok(esri?.constructionFallback);
  assert.equal(esri?.constructionFallback.id, "osm");
  assert.equal(esri?.tileFailureFallback?.threshold, 2);
});
