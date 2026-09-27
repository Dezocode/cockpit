// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/maps/imagery.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: drop ion imagery; add NaturalEarthII factory.
import * as Cesium from 'cesium';

export const ESRI_TILE_HOST = "services.arcgisonline.com";
export const OSM_TILE_HOST = "tile.openstreetmap.org";

export const ESRI_ATTRIBUTION_HTML =
  '<a href="https://www.esri.com" target="_blank" rel="noopener">Powered by Esri</a>';

export function createNaturalEarthImagery() {
  return Cesium.TileMapServiceImageryProvider.fromUrl(
    Cesium.buildModuleUrl('Assets/Textures/NaturalEarthII'),
  );
}

export function createOsmImagery() {
  return new Cesium.OpenStreetMapImageryProvider({
    url: 'https://tile.openstreetmap.org/',
    credit: '© OpenStreetMap contributors',
  });
}

export function createEsriImagery() {
  return Cesium.ArcGisMapServerImageryProvider.fromUrl(
    'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer',
    {
      credit:
        'Powered by Esri — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community',
      enablePickFeatures: false,
    },
  );
}
