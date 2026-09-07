#!/usr/bin/env bash
# TUI harness — isolated TMUX_TMPDIR, no product-socket collision.
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
export TMUX_TMPDIR="${TMUX_TMPDIR:-/tmp/cockpit-harness-$$}"
export COCKPIT_CONFIG_HOME="${COCKPIT_CONFIG_HOME:-$TMUX_TMPDIR/config}"
mkdir -p "$TMUX_TMPDIR" "$COCKPIT_CONFIG_HOME/providers.d"

printf 'cockpit TUI harness (TMUX_TMPDIR=%s)\n\n' "$TMUX_TMPDIR"

pass=0
fail=0
for t in "$root"/tests/test-*.sh; do
  name="$(basename "$t")"
  if COCKPIT_CONFIG_HOME="$COCKPIT_CONFIG_HOME" TMUX_TMPDIR="$TMUX_TMPDIR" bash "$t" >/tmp/cockpit-harness-$name.log 2>&1; then
    printf '  ✓ %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  ✗ %s (see /tmp/cockpit-harness-%s.log)\n' "$name" "$name"
    fail=$((fail + 1))
  fi
done

printf '\nTUI harness: pass=%d fail=%d\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
