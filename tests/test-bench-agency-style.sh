#!/usr/bin/env bash
# t293u-next agency bar schemas — nesting, badges, top-chrome, multi-chip (source grep).
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
layout="$repo_root/stage/nvim/lua/config/cockpit-bench.lua"
bench_test="$repo_root/tests/test-bench.sh"

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
grep -Fq 'CockpitBenchAbsent' "$layout" ||
  fail 'missing ABSENT model badge highlight group'
grep -Fq 'in_cockpit_tmux' "$layout" ||
  fail 'missing tmux double-chrome guard'
grep -Fq 'soften_tmux_window_strip' "$layout" ||
  fail 'missing tmux strip softening for product-nav weight'
grep -Fq 'CockpitBenchPane' "$layout" ||
  fail 'missing solid pane background to quiet watermark bleed'
grep -Fq 'CockpitBenchTabBar' "$layout" ||
  fail 'missing product tabline band highlight (approved bar weight)'
grep -Fq 'apply_visual_quiet' "$layout" ||
  fail 'missing eob/ascii quiet helper (no ~ filler or box borders)'
grep -Fq 'WinSeparator' "$layout" ||
  fail 'missing invisible Miller column separators (no ascii vert rules)'
grep -Fq 'fillchars' "$layout" ||
  fail 'missing fillchars eob quieting for empty buffer tail'
grep -Fq 'chip_run_id_label' "$layout" ||
  fail 'missing fuller backlink chip id labels'
grep -Fq 'ghui  read-only' "$layout" ||
  fail 'missing subdued tmux tabline right chrome'
grep -Fq 'for i, link in ipairs(state.backlinks)' "$layout" ||
  fail 'missing multi-chip backlink loop (N chips for N sqlite rows)'
grep -Fq 'on_mouse' "$layout" ||
  fail 'missing mouse drill handler for dual touch+keyboard input'
grep -Fq 'map("j"' "$layout" ||
  fail 'missing keyboard j/k drill handler'
grep -Fq 'VimResized' "$layout" ||
  fail 'missing resize re-layout autocmd'

grep -Fq 'string.rep("-", inner) .. "+"' "$layout" &&
  fail 'legacy ASCII chip HR (+---+ corners) still present'
grep -Eq '\|.*center_text' "$layout" &&
  fail 'legacy ASCII chip pipe borders still present'
grep -Eq 'string\.rep\("[|+\\-]"' "$layout" &&
  fail 'legacy ASCII box/separator drawing still present'
grep -Fq 'CockpitBenchChipBorder' "$layout" &&
  fail 'legacy CockpitBenchChipBorder highlight group still present'
grep -Fq 'CodexCockpitBench' "$layout" &&
  fail 'legacy CodexCockpitBench augroup names still present'

# Fixture contract: nested parent + two worker_deck_run backlinks for multi-chip proof.
grep -Fq 'parent-run-001::abc1' "$bench_test" ||
  fail 'missing nested child fixture row for runs nesting'
grep -Fq "('parent-run-001', 'run-local-001', 'worker_deck_run')" "$bench_test" ||
  fail 'missing second backlink fixture row for multi-chip proof'

printf '%s\n' 'Bench agency style contract: PASS'

# harness/no-invalid-winseparator — bare option blanks product BENCH (E5108)
if rg -n 'vim\.o\.winseparator\s*=' stage/nvim/lua/config/cockpit-bench.lua; then
  echo 'FAIL: bare vim.o.winseparator (use fillchars only)' >&2
  exit 1
fi
if rg -n 'vim\.wo\[.*\]\.winseparator\s*=' stage/nvim/lua/config/cockpit-bench.lua | rg -v pcall; then
  echo 'FAIL: unguarded vim.wo.winseparator without pcall' >&2
  exit 1
fi
