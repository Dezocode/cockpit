// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/maps/catalog.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: keyless stacks only (no ion/Google entries).
export const MAP_STACKS = [
  {
    id: 'naturalearth',
    label: 'NaturalEarth',
    shortLabel: 'NE',
    kind: 'naturalearth',
    requiresIon: false,
  },
  {
    id: 'esri-imagery',
    label: 'Esri Satellite',
    shortLabel: 'SAT',
    kind: 'esri-imagery',
    requiresIon: false,
  },
  {
    id: 'osm',
    label: 'OSM',
    shortLabel: 'OSM',
    kind: 'osm',
    requiresIon: false,
  },
];
