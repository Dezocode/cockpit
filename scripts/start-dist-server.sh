#!/usr/bin/env bash
# Start compiled dist-server API (Hostinger systemd equivalent, local/dev).
# Requires: pnpm build && pnpm exec tsc -p tsconfig.server.json
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
export COCKPIT_INSTALL_ROOT="${COCKPIT_INSTALL_ROOT:-$root}"
export COCKPIT_HOSTINGER="${COCKPIT_HOSTINGER:-1}"
export COCKPIT_WEB_PORT="${COCKPIT_WEB_PORT:-8787}"

dist="$root/app/dist-server/index.js"
if [[ ! -f "$dist" ]]; then
  printf 'dist-server missing — building…\n'
  (cd "$root/app" && pnpm exec tsc -p tsconfig.server.json)
fi

exec node "$dist"
