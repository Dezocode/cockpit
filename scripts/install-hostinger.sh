#!/usr/bin/env bash
# Canonical Hostinger install — separate Cockpit root at /opt/cockpit.
# Subscription envelope only. DENY /root/.grok · saul-go · local Qwen/sol-v1.7.1
#
# Deploy semantics (single path):
#   rsync: -a --delete (mirror tree, drop removed files)
#   systemd: packaging/systemd/cockpit-web.service → restart (fail if unit missing)
#   nginx: packaging/nginx/cockpit.conf
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
# shellcheck source=../bin/cockpit-portable-lib
source "$root/bin/cockpit-portable-lib"
cockpit_has_systemd || { printf 'Hostinger install requires systemd (Linux)\n' >&2; exit 2; }
COCKPIT_INSTALL_ROOT="${COCKPIT_INSTALL_ROOT:-/opt/cockpit}"
export COCKPIT_HOSTINGER=1
# install.sh refuses the removed deploy gate; never forward it from the caller.
unset COCKPIT_INSTALL_HOSTINGER

case "$COCKPIT_INSTALL_ROOT" in
  /root/.grok*|*/saul-go*)
    printf 'DENY: Cockpit install root must not be %s\n' "$COCKPIT_INSTALL_ROOT"
    exit 1
    ;;
esac

printf 'cockpit Hostinger install → %s\n' "$COCKPIT_INSTALL_ROOT"

need_root() {
  [[ "$(id -u)" -eq 0 ]] || { printf 'Run as root for systemd/nginx: sudo %s\n' "$0"; exit 1; }
}

if [[ -d "$root/app" ]]; then
  command -v pnpm >/dev/null 2>&1 || { printf 'pnpm required\n'; exit 1; }
fi

# User-level helpers only. The web build runs exactly once, below, where a
# failure aborts the deploy (install.sh's optional build swallows errors).
COCKPIT_INSTALL_WEB_BUILD=0 "$root/install.sh"

if [[ -d "$root/app" ]]; then
  (cd "$root/app" && pnpm install && pnpm build && pnpm exec tsc -p tsconfig.server.json)
fi

need_root

id cockpit &>/dev/null || useradd -r -s /usr/sbin/nologin cockpit
install -d "$COCKPIT_INSTALL_ROOT"
rsync -a --delete \
  --exclude node_modules \
  --exclude .git \
  --exclude app/node_modules \
  "$root/" "$COCKPIT_INSTALL_ROOT/"

printf '  → pnpm install --prod in %s/app\n' "$COCKPIT_INSTALL_ROOT"
(cd "$COCKPIT_INSTALL_ROOT/app" && pnpm install --prod --frozen-lockfile)

chown -R cockpit:cockpit "$COCKPIT_INSTALL_ROOT"
chmod +x "$COCKPIT_INSTALL_ROOT/packaging/systemd/cockpit-web-heal.sh"

install -m 0644 "$COCKPIT_INSTALL_ROOT/packaging/systemd/cockpit-web.service" \
  /etc/systemd/system/cockpit-web.service
install -m 0644 "$COCKPIT_INSTALL_ROOT/packaging/nginx/cockpit.conf" \
  /etc/nginx/sites-available/cockpit.conf
ln -sf /etc/nginx/sites-available/cockpit.conf /etc/nginx/sites-enabled/cockpit.conf 2>/dev/null || true

systemctl daemon-reload
systemctl enable cockpit-web.service
systemctl restart cockpit-web.service

if nginx -t 2>/dev/null; then
  systemctl reload nginx 2>/dev/null || true
else
  printf '  ~ nginx: configure certbot then reload\n'
fi

"$root/scripts/hostinger-health.sh" --wait 30 || {
  journalctl -u cockpit-web -n 20 --no-pager 2>/dev/null || true
  printf 'Hostinger install: /api/health not green\n'
  exit 1
}
printf 'Hostinger install: health green\n'
