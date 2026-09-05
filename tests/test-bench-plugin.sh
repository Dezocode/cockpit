#!/usr/bin/env bash
# Bench plugin must fail closed; CPR must not respawn Agent.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-bench.XXXXXX)"
test_home="$test_root/home"
intercom_home="$test_root/intercom/proctor"
box_home="$test_root/bench-box"
fakebin="$test_root/bin"
log="$test_root/tmux.log"
fixture_root="$repo_root/tests/fixtures/bench"
mkdir -p "$test_home/.config/cockpit" "$test_home/.config/tmux" "$fakebin" \
  "$intercom_home/db" "$box_home/db"

cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT

export HOME="$test_home"
export PATH="$fakebin:$repo_root/bin:/usr/bin:/bin"
export FAKE_TMUX_LOG="$log"
export FAKE_COCKPIT_PROJECT="$test_root/project"
export COCKPIT_SESSION=cockpit-bench-test
printf '# test overlay\n' >"$HOME/.config/tmux/cockpit.conf"

cat >"$fakebin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_TMUX_LOG"
if [[ "${1:-}" == -L ]]; then
  shift 2
fi
case "${1:-}" in
  has-session|new-session|source-file|kill-server|set-option|set-hook|show-hooks) exit 0 ;;
  list-panes)
    if [[ "${*}" == *'@cockpit_role'* ]]; then
      printf '%%0 runtime\n%%1 bar\n'
    else
      printf '%%0\n'
    fi
    ;;
  show-options)
    case "$*" in
      *@cockpit_runtime*) printf 'codex\n' ;;
      *@cockpit_overlay_hash*) : ;;
      *) : ;;
    esac
    ;;
  display-message)
    case "$*" in
      *pane_current_path*) printf '%s\n' "$FAKE_COCKPIT_PROJECT" ;;
      *pane_pid*) printf '4242\n' ;;
      *session_name*) printf 'cockpit-bench-test\n' ;;
      *) printf '0\n' ;;
    esac
    ;;
  list-clients) : ;;
  *) : ;;
esac
EOF
chmod +x "$fakebin/tmux"

bench="$repo_root/bin/cockpit-bench"

missing_output="$("$bench" check 2>&1 || true)"
grep -Eqi 'unavailable|no bench receipt' <<<"$missing_output"

cp -a "$fixture_root/." "$box_home/"
export COCKPIT_BENCH_HOME="$box_home"
box_check="$("$bench" check)"
grep -q '^status=ok$' <<<"$box_check"
grep -q '^model_count=2$' <<<"$box_check"
grep -q '^run_count=3$' <<<"$box_check"
grep -q '^source=box$' <<<"$box_check"

models_output="$("$bench" models)"
grep -q $'qwen3.5-4b\tQwen3.5-4B' <<<"$models_output"

runs_output="$("$bench" runs qwen3.5-4b)"
grep -q $'run-001\tdezohost\t0\tcomplete\tok' <<<"$runs_output"
grep -q $'run-002\tfrontier-vm\t1\tcomplete\tok' <<<"$runs_output"

show_output="$("$bench" show-run run-001)"
grep -q $'run-001\tqwen3.5-4b\tdezohost\t0\tcomplete' <<<"$show_output"
grep -q $'backlink\trun-002\tqwen3.5-4b\tfrontier-vm\t1\tcrossref' <<<"$show_output"

absent_run="$("$bench" runs llama-3.1-8b)"
grep -q 'ABSENT' <<<"$absent_run"

rm -rf "$box_home"
unset COCKPIT_BENCH_HOME
cp -a "$fixture_root/." "$intercom_home/"
export COCKPIT_INTERCOM_HOME="$test_root/intercom"
intercom_check="$("$bench" check)"
grep -q '^source=intercom$' <<<"$intercom_check"

list_output="$(cockpit-plugin list)"
grep -q '^cockpit\.bench[[:space:]]' <<<"$list_output"

run_output="$(cockpit-plugin run cockpit.bench check)"
grep -q '^status=ok$' <<<"$run_output"

bench_cli_output="$(bench check)"
grep -q '^status=ok$' <<<"$bench_cli_output"

cpr_output="$(cockpit-plugin cpr --apply 2>&1)"
grep -q '^overlay_validation=ok$' <<<"$cpr_output"
grep -q '^pane_processes_respawned=0$' <<<"$cpr_output"
grep -q 'BENCH' <<<"$cpr_output"

if grep -Ev -- '(^| )-L ' "$log" | grep -Eq '(^| )(respawn-pane|kill-session|new-window|swap-pane)( |$)'; then
  printf 'CPR issued a destructive live tmux command:\n' >&2
  sed -n '1,160p' "$log" >&2
  exit 1
fi

printf '%s\n' 'Bench plugin regression: PASS'
