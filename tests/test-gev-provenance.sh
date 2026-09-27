#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

PORTMAP="$root/third_party/gods-eye-view/PORTMAP.tsv"
if [[ ! -f "$PORTMAP" ]]; then
  echo "gev-provenance: missing PORTMAP" >&2
  exit 1
fi

rows=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  mode="$(echo "$line" | awk -F'\t' '{print $4}')"
  dest="$(echo "$line" | awk -F'\t' '{print $3}')"
  [[ "$mode" == "TRIVIAL" ]] && continue
  rows=$((rows + 1))
  if [[ ! -e "$root/$dest" ]]; then
    echo "gev-provenance: missing $dest" >&2
    exit 1
  fi
done < "$PORTMAP"

must_absent() {
  git ls-files | rg -i 'telegeography|bhote|local_data/|public/models/|public/events/' && exit 1 || true
  rg -il 'telegeography|bhoteKoshi|submarineCables' app && exit 1 || true
  rg -n "from ['\"]cesium['\"]|import\(['\"]cesium['\"]\)" app/src | rg -v '^app/src/panels/godseye/' && exit 1 || true
  rg -n 'vite-plugin-cesium' app/package.json app/vite.config.ts && exit 1 || true
  rg -n 'Ion\.defaultAccessToken' app/src && exit 1 || true
  rg -n 'import\.meta\.env\.(CESIUM_ION_TOKEN|GOOGLE_MAPS_API_KEY)' app/src && exit 1 || true
  rg -n "(CESIUM_ION_TOKEN|GOOGLE_MAPS_API_KEY)['\"]?\s*:" app/vite.config.ts && exit 1 || true
  rg -n 'ip-api|ipinfo|geoip|ipapi' app && exit 1 || true
  missing=$(rg --files-without-match 'Ported from bilawalsidhu/gods-eye-view@b210ab0' \
    app/src/panels/godseye/gev/*.js app/src/panels/godseye/gev/maps/*.js \
    app/src/panels/godseye/layers/fleetNodes.ts app/src/panels/godseye/layers/fleetSource.ts || true)
  if [[ -n "$missing" ]]; then echo "$missing" >&2; exit 1; fi
  rg -n 'createIonImagery|createWorldTerrain\b|IonImageryProvider|IonWorldImageryStyle|Cesium3DTileset|createGooglePhotorealistic|selectMapStartupRoute' app/src && exit 1 || true
  test -e app/src/panels/godseye/gev/mapStartup.js -o -e app/src/panels/godseye/gev/maps/google3d.js -o -e app/src/panels/godseye/gev/maps/availability.js && exit 1 || true
  rg -n 'keySetupCore|/api/setup/' app/src/panels/godseye && exit 1 || true
  rg -il 'opensky|aisstream|firms|tomtom|cctv|celestrak|earthquake\.usgs\.gov' app/src/panels/godseye app/server/fleet && exit 1 || true
  rg -n 'new (Cesium\.)?Viewer\(' app/src | rg -v '^app/src/panels/godseye/gev/viewer\.js:' && exit 1 || true
  rg -n 'zoomEventTypes|CameraEventType\.WHEEL' app/src | rg -v '^app/src/panels/godseye/gev/viewer\.js:' && exit 1 || true
  rg -n 'requestRenderMode|maximumRenderTimeChange' app/src | rg -v '^app/src/panels/godseye/gev/renderGovernor(\.test\.mjs|\.js):' && exit 1 || true
  rg -n 'addStaticCredit|new (Cesium\.)?Credit\(' app/src | rg -v '^app/src/panels/godseye/gev/maps/credits\.js:' && exit 1 || true
  rg -n 'terrain\.reearth\.land|arcgisonline\.com|tile\.openstreetmap\.org' app/src | rg -v '^app/src/panels/godseye/gev/maps/(imagery|terrain)\.js:' && exit 1 || true
  rg -n "defaultId:\s*['\"](esri-imagery|osm|photoreal)['\"]" app/src/panels/godseye && exit 1 || true
  rg -n "allowedHosts:\s*true|host:\s*['\"](0\.0\.0\.0|::)['\"]" app/vite.config.ts app/server/fleet && exit 1 || true
  rg -n '#[0-9a-fA-F]{3,8}\b|rgba?\(|Color\.(CYAN|MAGENTA|WHITE|BLACK|RED|GREEN|YELLOW|BLUE|ORANGE|GRAY|GREY|LIME|AQUA)\b' app/src/panels/godseye && exit 1 || true
  rg -n "\.(put|delete)\(\s*['\"](/api)?/keys|/api/keys\b" app/src app/server && exit 1 || true
  rg -n 'security add-generic-password|secret-tool store' bin app && exit 1 || true
}

must_absent

rg -n 'naturalearth' app/src/panels/godseye/gev/maps/defaultSources.js >/dev/null
rg -n 'vite-plugin-static-copy' app/package.json >/dev/null
rg -n '"cesium": "1\.138\.0"' app/package.json >/dev/null
rg -n -- '--cockpit-accent' app/src/panels/godseye/theme.ts >/dev/null

echo "gev-provenance: ok (${rows} rows, headers@b210ab0, no-nc-data)"
