#!/usr/bin/env bash
# t533u approved Miller ghui style contract (source grep, no live TTY).
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bench="$repo_root/bin/cockpit-bench"
spec="$repo_root/aspects/bench-ghui-approved-style-t533u.md"

fail() {
  printf 'Bench ghui style FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$spec" ]] || fail 'missing aspects/bench-ghui-approved-style-t533u.md'

grep -Fq 'cockpit · MEMORY  COMPUTERS  MODELS  BENCH  FILES  PRS' "$bench" ||
  fail 'missing approved top-left nav chrome'
grep -Fq 'BENCH  ghui  read-only' "$bench" ||
  fail 'missing approved top-right status chrome'
grep -Fq 't524u ghui' "$bench" ||
  fail 'missing approved footer t524u ghui line'
grep -Fq 'Backlinks (Enter → jump)' "$bench" ||
  fail 'missing yellow backlinks header string'
grep -Fq 'Run + backlinks' "$bench" ||
  fail 'missing Miller column header Run + backlinks'
grep -Fq 'draw_models_col' "$bench" ||
  fail 'missing Miller models column renderer'
grep -Fq 'draw_runs_col' "$bench" ||
  fail 'missing Miller runs column renderer'
grep -Fq 'draw_detail_col' "$bench" ||
  fail 'missing Miller detail column renderer'
grep -Fq 'draw_vrules' "$bench" ||
  fail 'missing Miller vertical column separators'

printf '%s\n' 'Bench ghui style contract: PASS'
