#!/usr/bin/env bash
# Hostinger fresh-install via grok-build subscription runtime lane
# Uses Hostinger VPS + grok CLI auth (not Cursor-only). Fail-closed without auth.
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
export COCKPIT_INSTALL_HOSTINGER=1
export COCKPIT_INSTALL_WEB_BUILD=1
export COCKPIT_HOSTINGER=1

printf 'cockpit Hostinger grok-build install lane\n'

# grok-build CLI — subscription runtime on Hostinger (parallel to gh/codex auth)
if command -v grok >/dev/null 2>&1; then
  if grok auth status >/dev/null 2>&1; then
    printf '  ✓ grok-build auth present\n'
  else
    printf '  → grok auth login (Hostinger subscription runtime)\n'
    grok auth login || { printf '  ✗ grok auth required for Hostinger lane\n'; exit 1; }
  fi
else
  printf '  ~ grok CLI not on PATH — install via Hostinger Node runtime or mise\n'
  printf '    mise use -g npm:@xai/grok 2>/dev/null || true\n'
fi

# gh still required for splash/setup (local state, no secrets in repo)
if ! gh auth status -h github.com >/dev/null 2>&1; then
  printf '  → gh auth login -h github.com -p https -w\n'
  gh auth login -h github.com -p https -w
fi

"$root/install.sh"

# Build web if not already
if [[ -d "$root/app" ]]; then
  (cd "$root/app" && pnpm install && pnpm build && pnpm exec tsc -p tsconfig.server.json)
  install -d /opt/cockpit
  cp -a "$root/." /opt/cockpit/
fi

if [[ "$(id -u)" -eq 0 ]]; then
  systemctl daemon-reload
  systemctl enable cockpit-web.service
  systemctl restart cockpit-web.service || systemctl start cockpit-web.service
  nginx -t && systemctl reload nginx || printf '  ~ configure nginx + certbot per deploy/README.md\n'
fi

port="${COCKPIT_WEB_PORT:-8787}"
for _ in $(seq 1 20); do
  if curl -sf "http://127.0.0.1:$port/api/health" >/dev/null 2>&1; then
    curl -s "http://127.0.0.1:$port/api/health" | python3 -m json.tool
    printf 'Hostinger health: green\n'
    exit 0
  fi
  sleep 0.5
done

printf '  ✗ /api/health not green — check journalctl -u cockpit-web\n'
exit 1
