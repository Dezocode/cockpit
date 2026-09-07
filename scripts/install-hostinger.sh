#!/usr/bin/env bash
# Hostinger install — separate Cockpit root at /opt/cockpit
# Subscription envelope only. DENY /root/.grok · saul-go · local Qwen/sol-v1.7.1
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
COCKPIT_INSTALL_ROOT="${COCKPIT_INSTALL_ROOT:-/opt/cockpit}"
export COCKPIT_INSTALL_HOSTINGER=1
export COCKPIT_INSTALL_WEB_BUILD=1
export COCKPIT_HOSTINGER=1

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

# User + TUI helpers (non-destructive to Surface tmux)
export COCKPIT_INSTALL_WEB_BUILD=1
"$root/install.sh"

# Web build
if [[ -d "$root/app" ]]; then
  command -v pnpm >/dev/null 2>&1 || { printf 'pnpm required\n'; exit 1; }
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

port="${COCKPIT_WEB_PORT:-8787}"
for _ in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:$port/api/health" >/dev/null 2>&1; then
    curl -s "http://127.0.0.1:$port/api/health" | python3 -m json.tool
    printf 'Hostinger install: health green\n'
    exit 0
  fi
  sleep 0.5
done

journalctl -u cockpit-web -n 20 --no-pager 2>/dev/null || true
printf 'Hostinger install: /api/health not green\n'
exit 1
