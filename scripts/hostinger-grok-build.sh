#!/usr/bin/env bash
# Hostinger grok-build lane — subscription runtime auth + install-hostinger.sh
# Uses grok-build CLI on Hostinger. Does NOT touch /root/.grok or saul-go.
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
export COCKPIT_INSTALL_ROOT="${COCKPIT_INSTALL_ROOT:-/opt/cockpit}"

printf 'cockpit hostinger-grok-build (subscription only)\n'

# grok-build subscription — fail-closed without auth
if command -v grok >/dev/null 2>&1; then
  if grok auth status >/dev/null 2>&1; then
    printf '  ✓ grok-build auth\n'
  else
    printf '  → grok auth login (Hostinger subscription)\n'
    grok auth login
  fi
else
  printf '  ✗ grok CLI missing — install via Hostinger Node runtime\n'
  exit 1
fi

# gh for splash/device-flow (OS keyring — no secrets in repo)
if ! gh auth status -h github.com >/dev/null 2>&1; then
  printf '  → gh auth login -h github.com -p https -w\n'
  gh auth login -h github.com -p https -w
fi

exec "$root/scripts/install-hostinger.sh"
