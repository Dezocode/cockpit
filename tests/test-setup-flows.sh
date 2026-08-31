#!/usr/bin/env bash
# Exercise the persistent SETUP dispatch and the user-confirmed Codex plugin
# flow without touching the real marketplace or tmux session.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-setup-test.XXXXXX)"
test_home="$test_root/home"
fakebin="$test_root/bin"
plugin_log="$test_root/plugin-add.log"
mkdir -p "$test_home/.config/cockpit" "$test_home/.grok" "$fakebin"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

export HOME="$test_home"
export COCKPIT_AUTH_HOME="$HOME/.config/cockpit"
export COCKPIT_SESSION=cockpit-setup-test
export COCKPIT_AUTH_TIMEOUT=0.2s
export FAKE_PLUGIN_LOG="$plugin_log"
export PATH="$fakebin:$repo_root/bin:/usr/bin:/bin"
unset TMUX TMUX_PANE

cat >"$COCKPIT_AUTH_HOME/providers.conf" <<'EOF'
[github]
label=GitHub
kind=cli-oauth
check=command -v gh
auth_check=gh auth status -h github.com

[codex]
label=Codex
kind=runtime
check=command -v codex
probe=codex-login
login=codex login
start=codex

[grok]
label=Grok
kind=runtime
check=command -v grok
probe=grok-cache
login=grok login --oauth
start=grok
EOF

cat >"$HOME/.grok/auth.json" <<'EOF'
{"session":{"auth_mode":"oidc","key":"access-key","refresh_token":"refresh-token","expires_at":"2099-01-01T00:00:00Z"}}
EOF

cat >"$fakebin/codex" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  'login status') exit 0 ;;
  'plugin list --available --json')
    printf '%s\n' '{"installed":[],"available":[{"pluginId":"demo@local","version":"1.0.0","installed":false}]}'
    ;;
  'plugin add demo@local')
    printf '%s\n' "$*" >"$FAKE_PLUGIN_LOG"
    ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$fakebin/codex"
ln -s /bin/true "$fakebin/gh"
ln -s /bin/true "$fakebin/grok"

set +e
plugin_output="$(printf '1\ny\nx\n\nq\n' | timeout 8s "$repo_root/bin/cockpit-setup" plugins 2>&1)"
plugin_status=$?
set -e
[[ "$plugin_status" == 0 ]]
grep -q 'CODEX PLUGINS' <<<"$plugin_output"
grep -q 'demo@local' <<<"$plugin_output"
grep -q 'OAuth ready' <<<"$plugin_output"
[[ "$(<"$plugin_log")" == 'plugin add demo@local' ]]

set +e
audit_output="$(printf 'x' | timeout 8s "$repo_root/bin/cockpit-setup" audit 2>&1)"
audit_status=$?
set -e
[[ "$audit_status" == 0 ]]
grep -q 'COCKPIT AUDIT' <<<"$audit_output"
grep -q 'tmux session is not running' <<<"$audit_output"

printf '%s\n' 'SETUP flow regression: PASS'
