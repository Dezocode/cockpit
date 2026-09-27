#!/usr/bin/env bash
set -euo pipefail

if ! command -v launchctl >/dev/null 2>&1; then
  printf 'launchd: skip (no launchctl)\n'
  exit 0
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() {
  printf 'launchd: FAIL (%s)\n' "$1"
  exit 1
}

home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT
export HOME="$home"

PATH="$repo_root/bin:$PATH" COCKPIT_INSTALL_SERVICE=1 SHELL=/bin/bash \
  /bin/bash "$repo_root/install.sh" </dev/null >/dev/null 2>&1

plist="${HOME}/Library/LaunchAgents/com.dezocode.cockpit-web.plist"
[[ -f "$plist" ]] || fail "plist missing"
plutil -lint "$plist" >/dev/null 2>&1 || fail "plist lint"

for _ in $(seq 1 80); do
  if curl -sf http://127.0.0.1:8787/api/health >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
if ! curl -sf http://127.0.0.1:8787/api/health >/dev/null 2>&1; then
  logfile="${HOME}/Library/Logs/cockpit-web.log"
  [[ -f "$logfile" ]] && sed -n '1,80p' "$logfile" >&2 || true
  fail "health"
fi

uid="$(id -u)"
launchctl bootout "gui/$uid" "$plist" 2>/dev/null || launchctl bootout "user/$uid" "$plist" 2>/dev/null || true

PATH="$repo_root/bin:$PATH" COCKPIT_INSTALL_SERVICE=1 SHELL=/bin/bash \
  /bin/bash "$repo_root/install.sh" </dev/null >/dev/null 2>&1

printf 'launchd: ok (plist lint, bootstrap, /api/health)\n'
