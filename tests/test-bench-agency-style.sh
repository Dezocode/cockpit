#!/usr/bin/env bash
# t293u agency bar schemas — nesting, badges, top-chrome, multi-chip (source grep).
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
layout="$repo_root/stage/nvim/lua/config/cockpit-bench.lua"

fail() {
  printf 'Bench agency style FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$layout" ]] || fail 'missing stage/nvim/lua/config/cockpit-bench.lua'

grep -Fq 'build_run_display' "$layout" ||
  fail 'missing nested runs display builder'
grep -Fq 'parent_run_id' "$layout" ||
  fail 'missing parent run_id helper for L3 header'
grep -Fq 'is_child_run' "$layout" ||
  fail 'missing child run detector for runs nesting'
grep -Fq 'entry.depth' "$layout" ||
  fail 'missing indented child rows in runs column'
grep -Fq 'CockpitBenchNavBrand' "$layout" ||
  fail 'missing cyan cockpit brand for top-chrome weight'
grep -Fq 'CockpitBenchBadgeDim' "$layout" ||
  fail 'missing dim model badge highlight group'
grep -Fq 'in_cockpit_tmux' "$layout" ||
  fail 'missing tmux double-chrome guard'
grep -Fq 'chip_run_id_label' "$layout" ||
  fail 'missing fuller backlink chip id labels'
grep -Fq 'ghui  read-only' "$layout" ||
  fail 'missing subdued tmux tabline right chrome'

grep -Fq 'string.rep("-", inner) .. "+"' "$layout" &&
  fail 'legacy ASCII chip HR (+---+ corners) still present'
grep -Eq '\|.*center_text' "$layout" &&
  fail 'legacy ASCII chip pipe borders still present'

printf '%s\n' 'Bench agency style contract: PASS'
