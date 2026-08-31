#!/usr/bin/env bash
# CPR must validate safely and avoid live-pane respawns by default.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-cpr.XXXXXX)"
test_home="$test_root/home"
fakebin="$test_root/bin"
log="$test_root/tmux.log"
mkdir -p "$test_home/.config/tmux" "$fakebin" "$test_root/project"
cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT

export HOME="$test_home"
export PATH="$fakebin:$repo_root/bin:/usr/bin:/bin"
export FAKE_TMUX_LOG="$log"
export FAKE_COCKPIT_PROJECT="$test_root/project"
export COCKPIT_SESSION=cockpit-cpr-test
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
      *session_name*) printf 'cockpit-cpr-test\n' ;;
      *) printf '0\n' ;;
    esac
    ;;
  list-clients) : ;;
  *) : ;;
esac
EOF
chmod +x "$fakebin/tmux"

output="$(cockpit-plugin cpr --apply 2>&1)"
grep -q '^overlay_validation=ok$' <<<"$output"
grep -q '^mode=applied$' <<<"$output"
grep -q '^pane_processes_respawned=0$' <<<"$output"
grep -q '^derived_processes_respawned=0$' <<<"$output"

if grep -Ev -- '(^| )-L ' "$log" | grep -Eq '(^| )(respawn-pane|kill-session|new-window|swap-pane)( |$)'; then
  printf 'CPR issued a destructive live tmux command:\n' >&2
  sed -n '1,160p' "$log" >&2
  exit 1
fi
grep -q 'source-file /tmp/' "$log"

printf '%s\n' 'CPR plugin regression: PASS'
