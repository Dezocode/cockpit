#!/usr/bin/env bash
# Hostinger grok-build lane (gospel deploy recipe)
# Envelope: frontier_subscription / grok-build ONLY.
# DENY: local Qwen · sol-v1.7.1 · Funnel · secrets bake · /root/.grok · saul-go
# Install root: /opt/cockpit — separate from Saul paths.
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
export COCKPIT_INSTALL_ROOT="${COCKPIT_INSTALL_ROOT:-/opt/cockpit}"
export COCKPIT_HOSTINGER=1

printf 'cockpit hostinger-grok-build (subscription only)\n'
printf '  envelope: frontier_subscription · Funnel OFF · no secrets bake\n'

case "$COCKPIT_INSTALL_ROOT" in
  /root/.grok*|*/saul-go*)
    printf 'DENY: Cockpit install root must not be %s (Saul paths untouched)\n' "$COCKPIT_INSTALL_ROOT"
    exit 1
    ;;
esac

if [[ -n "${COCKPIT_ALLOW_LOCAL_QWEN:-}" || -n "${QWEN_MODEL_PATH:-}" || -n "${SOL_V171_MODEL:-}" ]]; then
  printf 'DENY: local Qwen/sol-v1.7.1 not permitted on Hostinger grok-build lane\n'
  exit 1
fi

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
