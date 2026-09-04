#!/usr/bin/env bash
# Computers plugin must fail closed; CPR must not respawn Agent.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-computers.XXXXXX)"
test_home="$test_root/home"
intercom_home="$test_root/intercom"
fakebin="$test_root/bin"
log="$test_root/tmux.log"
mkdir -p "$test_home/.config/cockpit" "$test_home/.config/tmux" "$fakebin" \
  "$intercom_home/models" "$intercom_home/computers"

cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT

export HOME="$test_home"
export COCKPIT_INTERCOM_HOME="$intercom_home"
export PATH="$fakebin:$repo_root/bin:/usr/bin:/bin"
export FAKE_TMUX_LOG="$log"
export FAKE_COCKPIT_PROJECT="$test_root/project"
export COCKPIT_SESSION=cockpit-computers-test
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
      *session_name*) printf 'cockpit-computers-test\n' ;;
      *) printf '0\n' ;;
    esac
    ;;
  list-clients) : ;;
  *) : ;;
esac
EOF
chmod +x "$fakebin/tmux"

computers="$repo_root/bin/cockpit-computers"
fixture="$repo_root/tests/fixtures/computers-receipt.tsv"
json_fixture="$repo_root/tests/fixtures/deck.json"
json_sol_fixture="$repo_root/tests/fixtures/deck-sol.json"

missing_output="$("$computers" check 2>&1 || true)"
grep -Eqi 'missing|no managed receipt' <<<"$missing_output"

install -m 0644 "$json_fixture" "$intercom_home/models/deck.json"
install -m 0644 "$fixture" "$intercom_home/computers/receipt.tsv"

path_output="$("$computers" path)"
grep -Fxq "$intercom_home/models/deck.json" <<<"$path_output"

check_output="$("$computers" check)"
grep -q '^status=ok$' <<<"$check_output"
grep -q '^device_count=1$' <<<"$check_output"

roster_output="$("$computers" roster)"
grep -q $'dezodeck\tdeck\tnode\tonline' <<<"$roster_output"
if grep -q 'bench-vm' <<<"$roster_output"; then
  printf 'preferred JSON receipt leaked a legacy roster row\n' >&2
  exit 1
fi

models_output="$("$computers" models)"
grep -q $'dezodeck\tlocal/Qwen3.5-4B' <<<"$models_output"

install -m 0644 "$json_sol_fixture" "$intercom_home/models/deck-sol.json"
dual_check="$("$computers" check)"
grep -q '^device_count=2$' <<<"$dual_check"
dual_roster="$("$computers" roster)"
grep -q $'dezodeck\tdeck-sol\tnode\tonline' <<<"$dual_roster"
rm -f "$intercom_home/models/deck-sol.json"
grep -q '^device_count=1$' <<<"$("$computers" check)"

printf '%s\n' '{"schema":1,"node":"deck"}' >"$intercom_home/models/deck.json"
if "$computers" check >/dev/null 2>&1; then
  printf 'preferred JSON receipt did not fail closed\n' >&2
  exit 1
fi
install -m 0644 "$json_fixture" "$intercom_home/models/deck.json"

rm -f "$intercom_home/models/deck.json" "$intercom_home/computers/receipt.tsv"
project="$test_root/project"
mkdir -p "$project/models"
install -m 0644 "$json_fixture" "$project/models/deck.json"
cwd_path="$(COCKPIT_PROJECT="$project" "$computers" path)"
grep -Fxq "$project/models/deck.json" <<<"$cwd_path"
cwd_check="$(COCKPIT_PROJECT="$project" "$computers" check)"
grep -q '^status=ok$' <<<"$cwd_check"

install -m 0644 "$json_fixture" "$intercom_home/models/deck.json"

list_output="$(cockpit-plugin list)"
grep -q '^cockpit\.computers[[:space:]]' <<<"$list_output"

run_output="$(cockpit-plugin run cockpit.computers check)"
grep -q '^status=ok$' <<<"$run_output"

computers_cli_output="$(computers check)"
grep -q '^status=ok$' <<<"$computers_cli_output"

cpr_output="$(cockpit-plugin cpr --apply 2>&1)"
grep -q '^overlay_validation=ok$' <<<"$cpr_output"
grep -q '^mode=applied$' <<<"$cpr_output"
grep -q '^pane_processes_respawned=0$' <<<"$cpr_output"
grep -q '^derived_processes_respawned=0$' <<<"$cpr_output"
grep -q 'COMPUTERS' <<<"$cpr_output"

if grep -Ev -- '(^| )-L ' "$log" | grep -Eq '(^| )(respawn-pane|kill-session|new-window|swap-pane)( |$)'; then
  printf 'CPR issued a destructive live tmux command:\n' >&2
  sed -n '1,160p' "$log" >&2
  exit 1
fi

printf '%s\n' 'Computers plugin regression: PASS'
