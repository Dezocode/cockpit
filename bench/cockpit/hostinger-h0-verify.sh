#!/usr/bin/env bash
# Hostinger H0 done-line verifier — install.sh + systemd + nginx + /api/health
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
pass=0
fail=0

check() {
  local name=$1 result=$2
  if [[ "$result" == ok ]]; then
    printf '  ✓ %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  ✗ %s\n' "$name"
    fail=$((fail + 1))
  fi
}

printf 'Hostinger H0 verify (cockpit-20260907)\n\n'

grep -q 'COCKPIT_INSTALL_HOSTINGER' "$root/install.sh" && i=ok || i=fail
check "install.sh Hostinger gate" "$i"

[[ -f "$root/packaging/systemd/cockpit-web.service" ]] && s=ok || s=fail
check "systemd cockpit-web.service" "$s"

[[ -f "$root/packaging/nginx/cockpit.conf" ]] && n=ok || n=fail
check "nginx cockpit.conf" "$n"

[[ -x "$root/scripts/hostinger-grok-build.sh" ]] && g=ok || g=fail
check "grok-build install lane" "$g"

[[ -f "$root/app/dist-server/index.js" ]] || (cd "$root/app" && pnpm exec tsc -p tsconfig.server.json) 2>/dev/null
[[ -f "$root/app/dist-server/index.js" ]] && b=ok || b=fail
check "compiled API server (dist-server)" "$b"

port="${COCKPIT_WEB_PORT:-8787}"
if ! curl -sf "http://127.0.0.1:$port/api/health" >/dev/null 2>&1; then
  COCKPIT_HOSTINGER=1 pnpm --dir "$root/app" exec tsx server/index.ts &
  hp=$!
  trap 'kill $hp 2>/dev/null || true' EXIT
  for _ in $(seq 1 20); do
    curl -sf "http://127.0.0.1:$port/api/health" >/dev/null 2>&1 && break
    sleep 0.3
  done
fi

if curl -sf "http://127.0.0.1:$port/api/health" >/tmp/cockpit-h0-health.json 2>/dev/null; then
  status=$(python3 -c "import json; print(json.load(open('/tmp/cockpit-h0-health.json')).get('status',''))")
  [[ "$status" == green ]] && h=ok || h=fail
  check "/api/health green" "$h"
  cp /tmp/cockpit-h0-health.json "$root/bench/cockpit/screenshots/t384u/hostinger-health.json" 2>/dev/null || true
else
  check "/api/health green" fail
fi

printf '\nH0: pass=%d fail=%d\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
