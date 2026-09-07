#!/usr/bin/env bash
# Input matrix — keyboard vs touch modality (Foot size-owning preserved).
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
pass=0
fail=0

check() {
  [[ "$2" == ok ]] && { printf '  ✓ %s\n' "$1"; pass=$((pass + 1)); } || { printf '  ✗ %s\n' "$1"; fail=$((fail + 1)); }
}

printf 'Input matrix (keyboard · touch)\n\n'

[[ -x "$root/bin/cockpit-bar" ]] && check "TUI AGENT toolbar (cockpit-bar)" ok || check "TUI AGENT bar" fail
grep -q 'MouseDown1Pane' "$root/stage/tmux/cockpit.conf" 2>/dev/null && check "tmux touch MouseDown1Pane" ok || check "tmux touch" fail
grep -q 'termius-ios' "$root/bin/cockpit-adapt" 2>/dev/null && check "Termius iOS profile adapt" ok || check "Termius adapt" fail
grep -q '@cockpit_modality' "$root/bin/cockpit-main" 2>/dev/null && check "modality persisted (@cockpit_modality)" ok || check "modality" fail
grep -q 'AGENT_BAR_CHIPS' "$root/app/src/lib/types.ts" 2>/dev/null && check "GUI 6-chip bar contract" ok || check "GUI bar" fail

printf '\nInput matrix: pass=%d fail=%d\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
