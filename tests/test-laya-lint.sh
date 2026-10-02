#!/usr/bin/env bash
# C5 must_absent (gospels/C5.md): each probe must print nothing; each positive
# twin must print at least one line. Fail-closed: no rg, an rg error (exit 2),
# or a missing scan target is a finding, never a silent pass.
# LAYA_LINT_ROOT scans another tree (used to prove a planted hit is caught).
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${LAYA_LINT_ROOT:-$repo_root}"

if ! command -v rg >/dev/null 2>&1; then
  printf 'laya-lint: FAIL (ripgrep not on PATH; refusing to pass without scanning)\n' >&2
  exit 2
fi

findings=0
finding() {
  printf 'FAIL: %s\n' "$1" >&2
  findings=$((findings + 1))
}

# absent LABEL PATTERN [rg flags...] -- PATHS...: hits or rg errors are findings.
absent() {
  local label=$1 pattern=$2 flags=() paths=() out rc p
  shift 2
  while [[ $# -gt 0 && "$1" != -- ]]; do flags+=("$1"); shift; done
  shift
  paths=("$@")
  for p in "${paths[@]}"; do
    [[ -e "$p" ]] || { finding "$label: scan target missing: $p"; return 0; }
  done
  rc=0
  out="$(rg -n "${flags[@]}" -e "$pattern" -- "${paths[@]}" 2>&1)" || rc=$?
  case "$rc" in
    0) finding "$label"; printf '%s\n' "$out" >&2 ;;
    1) ;;
    *) finding "$label: rg exit $rc: $out" ;;
  esac
}

# twin LABEL PATTERN BAD GOOD [rg flags...]: probe hygiene. The pattern must
# match BAD (the evasion it exists for) and must not match GOOD (the correct
# code), so a probe that can never fire, or fires on the fix, is a finding.
twin() {
  local label=$1 pattern=$2 bad=$3 good=$4 rc
  shift 4
  rc=0
  printf '%s\n' "$bad" | rg -q "$@" -e "$pattern" || rc=$?
  [[ "$rc" == 0 ]] || finding "probe twin: $label does not match its bad example (rg exit $rc)"
  rc=0
  printf '%s\n' "$good" | rg -q "$@" -e "$pattern" || rc=$?
  [[ "$rc" == 1 ]] || finding "probe twin: $label matches its good example (rg exit $rc)"
}

present() {
  local label=$1 pattern=$2 rc=0 out
  shift 2
  out="$(rg -n -e "$pattern" -- "$@" 2>&1)" || rc=$?
  [[ "$rc" == 0 && -n "$out" ]] || finding "positive twin missing: $label (rg exit $rc)"
}

absent 'duplicated default-runtime literal' 'runtime_id=codex' -- bin
absent 'hard Laya dependency path' 'laya' -i -- app/package.json install.sh scripts/release-bundle.sh
absent 'Laya installed in CI' 'pip install[^\n]*laya|cockpit laya install' -- .github/workflows
absent 'non-loopback or overridable bind' '0\.0\.0\.0|LAYA_HOST=\$\{|LAYA_HOST:-' -- bin/cockpit-laya plugins/cockpit-laya
# [ ] keeps C3's portability lint from matching this pattern text itself.
absent 'GNU-only call' '\btimeout [0-9]|stat -c|readlink[ ]-f|sed[ ]-i|/proc/|\bsha256sum\b' -- bin/cockpit-laya bin/cockpit-route plugins/cockpit-laya
absent 'raw task text in receipts' '"task"\s*:' -- bin/cockpit-laya bin/cockpit-lib
# C3 schema mint (Thesis 11:49 CT): no runtime-assembled command names.
p_assembled='TOKEN_PART_|printf [^\n]*%s%s[^\n]*(laya|serve|mcp)|"l""aya"|chr\('
absent 'runtime-assembled command name' "$p_assembled" -- bin/cockpit-laya bin/cockpit-route bin/cockpit-lib plugins/cockpit-laya install.sh

# Negative/positive twins for every probe above (run on this tree's patterns).
twin 'duplicated default-runtime literal' 'runtime_id=codex' 'runtime_id=codex' 'runtime_id="$(cockpit_route_default)"'
twin 'hard Laya dependency path' 'laya' 'install -m 0644 "$root/stage/laya/laya.conf" x' 'for m in "$root"/plugins/*/plugin.conf; do' -i
twin 'Laya installed in CI' 'pip install[^\n]*laya|cockpit laya install' '        run: pip install laya' '  COCKPIT_LAYA: "0"'
twin 'non-loopback or overridable bind' '0\.0\.0\.0|LAYA_HOST=\$\{|LAYA_HOST:-' 'export LAYA_HOST="${LAYA_HOST:-127.0.0.1}"' '    export LAYA_HOST=127.0.0.1'
twin 'GNU-only call' '\btimeout [0-9]|stat -c|readlink[ ]-f|sed[ ]-i|/proc/|\bsha256sum\b' 'cmd="$(cat /proc/$pid/cmdline)"' 'cmd="$(ps -p "$pid" -o command=)"'
twin 'raw task text in receipts' '"task"\s*:' 'printf '"'"'{"task": %s}'"'"' "$t"' 'printf '"'"'{"task_sha256":%s}'"'"' "$sha"'
twin 'runtime-assembled command name' "$p_assembled" 'bin="$(printf '"'"'%s%s'"'"' lay a-serve)"' 'serve_bin="$(cockpit_laya_venv_bin laya-serve)"'
twin 'runtime-assembled command name (TOKEN_PART)' "$p_assembled" 'TOKEN_PART_1=lay; TOKEN_PART_2=a' 'mcp_bin="$(laya_mcp_bin)"'

present 'COCKPIT_LAYA: "0" in ci.yml' 'COCKPIT_LAYA: "0"' .github/workflows/ci.yml
present 'LAYA_HOST=127.0.0.1 in cockpit-laya' 'LAYA_HOST=127\.0\.0\.1' bin/cockpit-laya
present 'cockpit_route_default() in cockpit-lib' 'cockpit_route_default\(\)' bin/cockpit-lib

if ((findings > 0)); then
  printf 'laya-lint: %s findings\n' "$findings"
  exit 1
fi
printf 'laya-lint: 0 findings\n'
