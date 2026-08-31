#!/usr/bin/env bash
# Memory must fail closed without Intercom memory map and preserve Agent on CPR.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-memory.XXXXXX)"
test_home="$test_root/home"
fakebin="$test_root/bin"
log="$test_root/tmux.log"
mkdir -p "$test_home/.config/cockpit" "$test_home/.config/tmux" "$fakebin" "$test_root/intercom/memory"

cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT

export HOME="$test_home"
export PATH="$fakebin:$repo_root/bin:/usr/bin:/bin"
export COCKPIT_INTERCOM_HOME="$test_root/intercom"
export COCKPIT_AUTH_HOME="$HOME/.config/cockpit"
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

missing_output="$("$memory" status 2>&1 || true)"
grep -q '^memory_file=missing$' <<<"$missing_output"
grep -q "$COCKPIT_INTERCOM_HOME/memory/cockpit.mmd" <<<"$missing_output"

missing_validate="$("$memory" validate 2>&1 || true)"
grep -q '^memory_file=missing$' <<<"$missing_validate"

handshake_blocked="$("$memory" handshake 2>&1 || true)"
grep -q '^handshake=blocked$' <<<"$handshake_blocked"
grep -q '^launch=once$' <<<"$handshake_blocked"

install -D -m 0644 "$repo_root/tests/fixtures/cockpit-memory.mmd" \
  "$COCKPIT_INTERCOM_HOME/memory/cockpit.mmd"

present_output="$("$memory" status 2>&1)"
grep -q '^memory_file=valid$' <<<"$present_output"

validate_output="$("$memory" validate 2>&1)"
grep -q '^memory_file=ok$' <<<"$validate_output"

render_output="$("$memory" render 2>&1)"
grep -q 'index' <<<"$render_output"
grep -q 'intercom' <<<"$render_output"
grep -q 'hooks' <<<"$render_output"

handshake_ready="$("$memory" handshake 2>&1)"
grep -q '^handshake=ready$' <<<"$handshake_ready"

forbidden_file="$test_root/intercom/memory/cockpit-forbidden.mmd"
install -D -m 0644 "$COCKPIT_INTERCOM_HOME/memory/cockpit.mmd" "$forbidden_file"
printf '\n/workspace/aspects\n' >>"$forbidden_file"
forbidden_status="$(COCKPIT_MEMORY_FILE="$forbidden_file" "$memory" validate 2>&1 || true)"
grep -q 'forbidden pattern' <<<"$forbidden_status"

list_output="$(cockpit-plugin list)"
grep -q '^cockpit\.memory[[:space:]]' <<<"$list_output"

cpr_output="$(cockpit-plugin cpr --apply 2>&1)"
grep -q '^overlay_validation=ok$' <<<"$cpr_output"
grep -q '^mode=applied$' <<<"$cpr_output"
grep -q '^pane_processes_respawned=0$' <<<"$cpr_output"
grep -q '^derived_processes_respawned=0$' <<<"$cpr_output"
grep -q 'MEMORY' <<<"$cpr_output"

if grep -Ev -- '(^| )-L ' "$log" | grep -Eq '(^| )(respawn-pane|kill-session|new-window|swap-pane)( |$)'; then
  printf 'CPR issued a destructive live tmux command:\n' >&2
  sed -n '1,160p' "$log" >&2
  exit 1
fi

printf '%s\n' 'Memory plugin regression: PASS'
