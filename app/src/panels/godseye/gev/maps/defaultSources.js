// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/maps/defaultSources.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: keyless default; drop availability/keySetup/ion/Google branches.
import { MAP_STACKS } from './catalog.js';
import {
  createOsmImagery,
  createEsriImagery,
  createNaturalEarthImagery,
  ESRI_ATTRIBUTION_HTML,
} from './imagery.js';
import { createFlatTerrain, createKeylessTerrain } from './terrain.js';

/** Select sources without provider branches in the panel controller. */
export function createDefaultMapSources({
  imageryFactories = {
    naturalearth: createNaturalEarthImagery,
    osm: createOsmImagery,
    esri: createEsriImagery,
  },
  terrainFactories = {
    flat: createFlatTerrain,
    keyless: createKeylessTerrain,
  },
} = {}) {
  const flatTerrain = {
    id: 'flat',
    create: terrainFactories.flat,
  };
  const keylessTerrain = {
    id: 'keyless',
    create: terrainFactories.keyless,
  };
  return {
    defaultId: 'naturalearth',
    unknownId: 'naturalearth',
    recoveryId: null,
    state: { hasCesiumIonToken: false },
    sources: MAP_STACKS.map((descriptor) => {
      const common = {
        descriptor,
        available: true,
        unavailableReason: null,
      };
      if (descriptor.kind === 'naturalearth') {
        return {
          ...common,
          imagery: imageryFactories.naturalearth,
          terrain: flatTerrain,
          credit: 'Natural Earth II (public domain, bundled with Cesium)',
        };
      }
      const imagery =
        descriptor.id === 'osm'
          ? imageryFactories.osm
          : imageryFactories.esri;
      return {
        ...common,
        imagery,
        terrain: keylessTerrain,
        ...(descriptor.id === 'esri-imagery'
          ? {
              credit: ESRI_ATTRIBUTION_HTML,
              constructionFallback: {
                id: 'osm',
                message: 'Esri Satellite is unavailable; using OSM',
              },
              tileFailureFallback: {
                id: 'osm',
                threshold: 2,
                message: 'Esri Satellite tile requests failed; using OSM',
              },
            }
          : descriptor.id === 'osm'
            ? { credit: '© OpenStreetMap contributors' }
            : {}),
      };
    }),
  };
}

export function findMapSource(sources, id) {
  return sources.sources.find((entry) => entry.descriptor.id === id) ?? null;
}

export function resolveStackId(sources, requestedId) {
  const id = requestedId || sources.defaultId;
  const entry = findMapSource(sources, id);
  if (entry?.available) return id;
  return sources.defaultId;
}
