#!/usr/bin/env bash
# t533u approved Miller ghui style contract (nvim surface source grep).
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bench="$repo_root/bin/cockpit-bench"
layout="$repo_root/stage/nvim/lua/config/cockpit-bench.lua"
spec="$repo_root/aspects/bench-ghui-approved-style-t533u.md"

fail() {
  printf 'Bench ghui style FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$spec" ]] || fail 'missing aspects/bench-ghui-approved-style-t533u.md'
[[ -f "$layout" ]] || fail 'missing stage/nvim/lua/config/cockpit-bench.lua'

grep -Fq 'COCKPIT_NVIM_BENCH_LAYOUT_INIT' "$bench" ||
  fail 'cockpit-bench does not launch the nvim bench layout'
grep -Fq 'exec nvim' "$bench" ||
  fail 'cockpit-bench does not exec nvim like the FILES surface family'

grep -Fq 'cockpit · MEMORY  COMPUTERS  MODELS  BENCH  FILES  PRS' "$layout" ||
  fail 'missing approved top-left nav chrome'
grep -Fq 'BENCH  ghui  read-only' "$layout" ||
  fail 'missing approved top-right status chrome'
grep -Fq 't524u ghui' "$layout" ||
  fail 'missing approved footer t524u ghui line'
grep -Fq 'Backlinks (Enter → jump)' "$layout" ||
  fail 'missing yellow backlinks header string'
grep -Fq 'CockpitBenchGoldLabel' "$layout" ||
  fail 'missing punchy gold label highlight group'
grep -Fq 'PUNCH_GOLD_LABEL' "$layout" ||
  fail 'missing approved gold label chroma constant'
grep -Fq 'CockpitBenchNavRest' "$layout" ||
  fail 'missing flat nav tabline rest highlight'
grep -Fq 'GOLD_LABEL_BG' "$layout" ||
  fail 'missing gold label background punch'
grep -Fq 'Run + backlinks' "$layout" ||
  fail 'missing Miller column header Run + backlinks'
grep -Fq 'render_models_col' "$layout" ||
  fail 'missing Miller models column renderer'
grep -Fq 'render_runs_col' "$layout" ||
  fail 'missing Miller runs column renderer'
grep -Fq 'render_detail_col' "$layout" ||
  fail 'missing Miller detail column renderer'
grep -Fq 'draw_vrules' "$layout" ||
  fail 'missing Miller vertical column separators'

printf '%s\n' 'Bench ghui style contract: PASS'
