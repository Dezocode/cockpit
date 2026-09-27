// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/maps/terrain.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: drop ion world terrain factory.
import * as Cesium from 'cesium';

export async function createFlatTerrain() {
  return { provider: new Cesium.EllipsoidTerrainProvider() };
}

export async function createKeylessTerrain() {
  try {
    return {
      provider: await Cesium.CesiumTerrainProvider.fromUrl(
        'https://terrain.reearth.land/cesium-mesh/ellipsoid',
      ),
    };
  } catch (error) {
    console.warn(
      '[MapStack] Re:Earth terrain unavailable, falling back to flat ellipsoid terrain:',
      error,
    );
    return { provider: new Cesium.EllipsoidTerrainProvider() };
  }
}
