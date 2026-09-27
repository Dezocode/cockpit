#!/usr/bin/env bash
# Hostinger H0 done-line verifier — canonical install script + packaging + /api/health
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
# shellcheck source=lib/matrix.sh
source "$root/bench/cockpit/lib/matrix.sh"

matrix_begin 'Hostinger H0 verify (cockpit-20260907)'

[[ -x "$root/scripts/install-hostinger.sh" ]] && i=ok || i=fail
matrix_check "scripts/install-hostinger.sh (canonical deploy)" "$i"

! grep -q 'COCKPIT_INSTALL_HOSTINGER' "$root/install.sh" && ig=ok || ig=fail
matrix_check "install.sh has no Hostinger block" "$ig"

[[ -f "$root/packaging/systemd/cockpit-web.service" ]] && s=ok || s=fail
matrix_check "systemd cockpit-web.service" "$s"

[[ -f "$root/packaging/nginx/cockpit.conf" ]] && n=ok || n=fail
matrix_check "nginx cockpit.conf" "$n"

[[ -x "$root/scripts/hostinger-health.sh" ]] && hscript=ok || hscript=fail
matrix_check "scripts/hostinger-health.sh probe" "$hscript"

grep -q 'frontier_subscription\|DENY.*Qwen\|sol-v1\.7\.1' "$root/scripts/install-hostinger.sh" 2>/dev/null && ge=ok || ge=fail
matrix_check "install-hostinger envelope (subscription only)" "$ge"

[[ -f "$root/app/dist-server/index.js" ]] || (cd "$root/app" && pnpm exec tsc -p tsconfig.server.json) 2>/dev/null
[[ -f "$root/app/dist-server/index.js" ]] && b=ok || b=fail
matrix_check "compiled API server (dist-server)" "$b"

port="${COCKPIT_WEB_PORT:-8787}"
if ! curl -sf "http://127.0.0.1:$port/api/health" >/dev/null 2>&1; then
  COCKPIT_INSTALL_ROOT="$root" COCKPIT_HOSTINGER=1 node "$root/app/dist-server/index.js" &
  hp=$!
  trap 'kill $hp 2>/dev/null || true' EXIT
  bash "$root/scripts/hostinger-health.sh" --wait 30 >/dev/null || true
fi

if bash "$root/scripts/hostinger-health.sh" >/dev/null 2>&1; then
  status=$(python3 -c "import json; print(json.load(open('/tmp/cockpit-health-probe.json')).get('status',''))")
  source=$(python3 -c "import json; print(json.load(open('/tmp/cockpit-health-probe.json')).get('source',''))")
  [[ "$status" == green ]] && h=ok || h=fail
  matrix_check "/api/health green" "$h"
  [[ "$source" == "app/dist-server/index.js" ]] && hs=ok || hs=fail
  matrix_check "health source app/dist-server/index.js" "$hs"
  mkdir -p "$root/bench/cockpit/screenshots/t384u"
  cp /tmp/cockpit-health-probe.json "$root/bench/cockpit/screenshots/t384u/hostinger-health.json" 2>/dev/null || true
else
  matrix_check "/api/health green" fail
  matrix_check "health source app/dist-server/index.js" fail
fi

matrix_end
