#!/usr/bin/env bash
# CPR must validate safely and avoid live-pane respawns by default.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init cpr-plugin
test_root="$FIXTURE_TEST_ROOT"
test_home="$FIXTURE_HOME"
fakebin="$FIXTURE_FAKEBIN"
log="$test_root/tmux.log"
mkdir -p "$test_home/.config/tmux" "$test_root/project"

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
while [[ "${1:-}" == -f ]]; do
  shift 2
done
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

set +e
output="$(cockpit-plugin cpr --apply 2>&1)"
cpr_rc=$?
set -e
[[ "$cpr_rc" == 0 ]] || {
  printf 'CPR plugin exited %s:\n%s\n' "$cpr_rc" "$output" >&2
  exit 1
}
grep -q '^overlay_validation=ok$' <<<"$output" || {
  printf 'CPR output missing overlay_validation=ok:\n%s\n' "$output" >&2
  exit 1
}
grep -q '^mode=applied$' <<<"$output"
grep -q '^pane_processes_respawned=0$' <<<"$output"
grep -q '^derived_processes_respawned=0$' <<<"$output"

if grep -Ev -- '(^| )-L ' "$log" | grep -Eq '(^| )(respawn-pane|kill-session|new-window|swap-pane)( |$)'; then
  printf 'CPR issued a destructive live tmux command:\n' >&2
  sed -n '1,160p' "$log" >&2
  exit 1
fi
grep -qE 'source-file .+cockpit\.conf' "$log" || {
  printf 'CPR tmux log missing source-file cockpit.conf:\n' >&2
  sed -n '1,80p' "$log" >&2
  exit 1
}

printf '%s\n' 'CPR plugin regression: PASS'
