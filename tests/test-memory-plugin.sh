#!/usr/bin/env bash
# Memory plugin must fail closed; CPR must not respawn Agent.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-memory.XXXXXX)"
test_home="$test_root/home"
intercom_home="$test_root/intercom"
fakebin="$test_root/bin"
log="$test_root/tmux.log"
mkdir -p "$test_home/.config/cockpit" "$test_home/.config/tmux" "$fakebin" "$intercom_home/memory"

cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT

export HOME="$test_home"
export COCKPIT_INTERCOM_HOME="$intercom_home"
export PATH="$fakebin:$repo_root/bin:/usr/bin:/bin"
export FAKE_TMUX_LOG="$log"
export FAKE_COCKPIT_PROJECT="$test_root/project"
export COCKPIT_SESSION=cockpit-memory-test
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
      *session_name*) printf 'cockpit-memory-test\n' ;;
      *) printf '0\n' ;;
    esac
    ;;
  list-clients) : ;;
  *) : ;;
esac
EOF
chmod +x "$fakebin/tmux"

memory="$repo_root/plugins/cockpit-memory/memory"
fixture="$repo_root/tests/fixtures/cockpit.mmd"

missing_output="$("$memory" check 2>&1 || true)"
grep -qi 'missing' <<<"$missing_output"

install -m 0644 "$fixture" "$intercom_home/memory/cockpit.mmd"

path_output="$("$memory" path)"
grep -Fxq "$intercom_home/memory/cockpit.mmd" <<<"$path_output"

check_output="$("$memory" check)"
grep -q '^status=ok$' <<<"$check_output"
grep -q '^subgraphs=index,intercom,hooks$' <<<"$check_output"

show_output="$("$memory" show)"
grep -q 'subgraph index' <<<"$show_output"
grep -q 'subgraph intercom' <<<"$show_output"
grep -q 'subgraph hooks' <<<"$show_output"
grep -qv 'subgraph Foundry' <<<"$show_output"
grep -qv 'subgraph PiSai' <<<"$show_output"
grep -qv 'Must not render' <<<"$show_output"

# cwd-relative fallback when Intercom clone is absent
rm -f "$intercom_home/memory/cockpit.mmd"
project="$test_root/project"
mkdir -p "$project/memory"
install -m 0644 "$fixture" "$project/memory/cockpit.mmd"
cwd_path="$(COCKPIT_PROJECT="$project" "$memory" path)"
grep -Fxq "$project/memory/cockpit.mmd" <<<"$cwd_path"
cwd_check="$(COCKPIT_PROJECT="$project" "$memory" check)"
grep -q '^status=ok$' <<<"$cwd_check"

install -m 0644 "$fixture" "$intercom_home/memory/cockpit.mmd"

list_output="$(cockpit-plugin list)"
grep -q '^cockpit\.memory[[:space:]]' <<<"$list_output"

run_output="$(cockpit-plugin run cockpit.memory check)"
grep -q '^status=ok$' <<<"$run_output"

memory_cli_output="$(memory check)"
grep -q '^status=ok$' <<<"$memory_cli_output"

cpr_output="$(cockpit-plugin cpr --apply 2>&1)"
grep -q '^overlay_validation=ok$' <<<"$cpr_output"
grep -q '^mode=applied$' <<<"$cpr_output"
grep -q '^pane_processes_respawned=0$' <<<"$cpr_output"
grep -q '^derived_processes_respawned=0$' <<<"$cpr_output"

if grep -Ev -- '(^| )-L ' "$log" | grep -Eq '(^| )(respawn-pane|kill-session|new-window|swap-pane)( |$)'; then
  printf 'CPR issued a destructive live tmux command:\n' >&2
  sed -n '1,160p' "$log" >&2
  exit 1
fi

printf '%s\n' 'Memory plugin regression: PASS'
