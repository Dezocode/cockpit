#!/usr/bin/env bash
# Pre-start heal for cockpit-web — verify install root, build artifacts, node.
# Install root: /opt/cockpit ONLY — never /root/.grok or saul-go.
set -euo pipefail

COCKPIT_INSTALL_ROOT="${COCKPIT_INSTALL_ROOT:-/opt/cockpit}"
APP="$COCKPIT_INSTALL_ROOT/app"
PORT="${COCKPIT_WEB_PORT:-8787}"

[[ -d "$COCKPIT_INSTALL_ROOT" ]] || { echo "heal: missing $COCKPIT_INSTALL_ROOT"; exit 1; }
[[ -f "$APP/dist-server/index.js" ]] || { echo "heal: missing dist-server — run install-hostinger.sh"; exit 1; }
[[ -f "$APP/dist/index.html" ]] || { echo "heal: missing web dist"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "heal: node not found"; exit 1; }

# Fail-closed: refuse Saul/grok local runtime paths as install root
case "$COCKPIT_INSTALL_ROOT" in
  /root/.grok*|*/saul-go*) echo "heal: DENY install root $COCKPIT_INSTALL_ROOT"; exit 1 ;;
esac

# Reap stale listener on our port (cockpit-web only)
if command -v fuser >/dev/null 2>&1; then
  fuser -k "${PORT}/tcp" 2>/dev/null || true
fi

echo "heal: ok root=$COCKPIT_INSTALL_ROOT port=$PORT"
