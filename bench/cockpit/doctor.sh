#!/usr/bin/env bash
# Cockpit doctor — preflight diagnostics
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"

printf 'cockpit doctor\n\n'

need_ok=0
need_fail=0

need() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '  ✓ %s (%s)\n' "$1" "$(command -v "$1")"
    need_ok=$((need_ok + 1))
  else
    printf '  ✗ %s missing\n' "$1"
    need_fail=$((need_fail + 1))
  fi
}

printf 'Toolchain:\n'
need tmux
need gh
need pnpm
need node
need cargo

printf '\nTUI:\n'
if [[ -x "$root/bin/cockpit" ]]; then
  printf '  ✓ cockpit CLI\n'
else
  printf '  ✗ cockpit CLI — run ./install.sh\n'
  need_fail=$((need_fail + 1))
fi

printf '\nGitHub auth:\n'
if gh auth status -h github.com >/dev/null 2>&1; then
  printf '  ✓ gh authenticated\n'
else
  printf '  ~ gh auth pending — gh auth login -h github.com -p https -w\n'
fi

printf '\nWeb API:\n'
if curl -sf "http://localhost:${COCKPIT_WEB_PORT:-8787}/api/health" >/dev/null 2>&1; then
  curl -s "http://localhost:${COCKPIT_WEB_PORT:-8787}/api/health" | python3 -m json.tool 2>/dev/null || true
else
  printf '  ~ cockpit-web not running — cd app && pnpm dev:web\n'
fi

printf '\nFoot size-owning:\n'
printf '  ℹ Foot remains size-owning on dezohost product socket (TUI preserved)\n'

printf '\ndoctor: ok=%d fail=%d\n' "$need_ok" "$need_fail"
[[ "$need_fail" -eq 0 ]]
