#!/usr/bin/env bash
# Surface capability matrix — TUI vs GUI parity (zero Surface regression).
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
pass=0
fail=0

check() {
  local name=$1 result=$2
  if [[ "$result" == ok ]]; then
    printf '  ✓ %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  ✗ %s\n' "$name"
    fail=$((fail + 1))
  fi
}

printf 'Surface capability matrix (TUI ↔ GUI)\n\n'

# Pages that must exist in BOTH surfaces
declare -A tui gui
for page in AGENT FILES DIFF SETUP MAP PRS MEMORY COMPUTERS BENCH; do
  case "$page" in
    AGENT|FILES|DIFF|SETUP|MAP|PRS)
      [[ -x "$root/bin/cockpit-main" ]] && tui[$page]=ok || tui[$page]=fail
      ;;
    MEMORY) [[ -x "$root/bin/cockpit-memory" ]] && tui[$page]=ok || tui[$page]=fail ;;
    COMPUTERS) [[ -x "$root/bin/cockpit-computers" ]] && tui[$page]=ok || tui[$page]=fail ;;
    BENCH) [[ -x "$root/bin/cockpit-bench" ]] && tui[$page]=ok || tui[$page]=fail ;;
  esac
  grep -rq "$page" "$root/app/src" 2>/dev/null && gui[$page]=ok || gui[$page]=fail
  [[ "${tui[$page]:-fail}" == ok && "${gui[$page]:-fail}" == ok ]] && check "$page TUI+GUI" ok || check "$page TUI+GUI" fail
done

# MODELS: GUI sub-view in COMPUTERS; TUI via SETUP model picker + COMPUTERS `m`
grep -rq ModelsView "$root/app/src/pages" 2>/dev/null && gv=ok || gv=fail
grep -q open_model "$root/bin/cockpit-bar" 2>/dev/null && tv=ok || tv=fail
[[ "$gv" == ok && "$tv" == ok ]] && check "MODELS (GUI m-view + TUI bar)" ok || check "MODELS (GUI m-view + TUI bar)" fail

# Foot size-owning — product socket preserved
grep -rq 'sizeOwning\|size-owning' "$root/app" "$root/bin" 2>/dev/null && check "Foot size-owning" ok || check "Foot size-owning" fail

# No product-socket kill — CPR + main still present
[[ -x "$root/bin/cockpit" && -x "$root/plugins/cockpit-cpr/cpr" ]] && check "product socket preserved (cockpit+cpr)" ok || check "product socket preserved" fail

# Product name
! grep -rq 'codex-cockpit' "$root/app/package.json" "$root/app/src-tauri/tauri.conf.json" 2>/dev/null && check "product cockpit (not codex-cockpit GUI)" ok || check "product cockpit GUI id" fail

# Funnel OFF
grep -rq 'Funnel OFF\|funnel.*OFF' "$root/app" 2>/dev/null && check "Funnel OFF" ok || check "Funnel OFF" fail

printf '\nSurface: pass=%d fail=%d\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
