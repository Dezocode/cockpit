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
grep -Fq 'status-position bottom' "$layout" ||
  fail 'missing tmux status-position bottom (t736u single product chrome row)'
grep -Fq "status-left ''" "$layout" ||
  fail 'missing tmux status-left blanking (subtract COCKPIT badge as product)'
grep -Fq 'CockpitBenchPane' "$layout" ||
  fail 'missing solid pane background to quiet watermark bleed'
grep -Fq 'CockpitBenchTabBar' "$layout" ||
  fail 'missing product tabline band highlight (approved bar weight)'
grep -Fq 'apply_visual_quiet' "$layout" ||
  fail 'missing eob/ascii quiet helper (no ~ filler or box borders)'
grep -Fq 'apply_omarchy_flat_bg' "$layout" ||
  fail 'missing omarchy-flat bench canvas (no Totoro/wallpaper bleed)'
grep -Fq 'OMARCHY_FLAT_BG' "$layout" ||
  fail 'missing OMARCHY_FLAT_BG constant (separate from visual-density PANE_BG)'
grep -Fq 'bg = colors.omarchy_flat' "$layout" ||
  fail 'Normal/canvas must use omarchy_flat bg (CockpitBenchFlat live canvas)'
grep -Fq 'window-style' "$layout" ||
  fail 'missing tmux window-style omarchy-flat pane bg (no wallpaper/Totoro bleed)'
grep -Fq 'winblend = 0' "$layout" ||
  fail 'missing winblend=0 guard for opaque omarchy-flat canvas'
grep -Fq 'pumblend = 0' "$layout" ||
  fail 'missing pumblend=0 guard for opaque omarchy-flat canvas'
grep -Fq 'CHIP_PAD_COLS' "$layout" ||
  fail 'missing chip pad for N separate yellow boxes (not one packed strip)'
grep -Fq 'CHIP_GAP_ROWS' "$layout" ||
  fail 'missing chip gap rows between N backlinks (not one packed strip)'
grep -Fq 'CockpitBenchChipEdge' "$layout" ||
  fail 'missing chip edge highlight for N separate yellow boxes (not one packed strip)'
grep -Fq 'paint_terminal_flat_bg' "$layout" ||
  fail 'missing OSC terminal flat bg paint (no Totoro/wallpaper bleed in pixel CPR)'
grep -Fq 'CockpitBenchTouchReceipts' "$layout" ||
  fail 'missing touch receipt counter (SGR click proof, not API remote-send)'
grep -Fq 'harness_runs_title' "$layout" ||
  fail 'missing harness_runs_title export for SGR touch drill assertion'
grep -Fq 'status off' "$layout" ||
  fail 'missing tmux status off on BENCH window (density: no 1:AGENT strip)'
grep -Fq "set-option -g window-style" "$layout" ||
  fail 'missing global tmux window-style omarchy-flat (survives omarchy-theme-set-tmux)'
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
grep -Fq 'touch_probe' "$layout" ||
  fail 'missing touch_probe harness hook (on_mouse path, not keyboard remote-send)'
grep -Fq 'vim.g.CockpitBench' "$layout" ||
  fail 'missing live CockpitBench instance for touch harness probe'
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
