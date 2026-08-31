#!/usr/bin/env bash
# Provider-owned auth probes must distinguish a usable session from a merely
# present auth file, including the pre-probe local providers.conf shape.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-auth-test.XXXXXX)"
test_home="$test_root/home"
fakebin="$test_root/bin"
mkdir -p "$test_home/.config/cockpit" "$test_home/.codex" "$test_home/.grok" "$fakebin"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

export HOME="$test_home"
export COCKPIT_AUTH_HOME="$HOME/.config/cockpit"
export PATH="$fakebin:$repo_root/bin:/usr/bin:/bin"

ln -s /bin/true "$fakebin/gh"
ln -s /bin/true "$fakebin/codex"
ln -s /bin/true "$fakebin/grok"

# This is intentionally the pre-probe config shape found on existing installs.
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
auth_check=test -s "$HOME/.codex/auth.json"
start=codex

[grok]
label=Grok
kind=runtime
check=command -v grok
auth_check=test -s "$HOME/.grok/auth.json"
start=grok
EOF

cat >"$HOME/.grok/auth.json" <<'EOF'
{"session":{"auth_mode":"oidc","key":"access-key","refresh_token":"refresh-token","expires_at":"2099-01-01T00:00:00Z"}}
EOF

# shellcheck source=../bin/cockpit-auth-lib
source "$repo_root/bin/cockpit-auth-lib"

[[ "$(cockpit_auth_state github)" == ready ]]
[[ "$(cockpit_auth_state codex)" == ready ]]
[[ "$(cockpit_auth_state grok)" == ready ]]
[[ "$(cockpit_auth_login_cmd codex)" == 'codex login' ]]
[[ "$(cockpit_auth_login_cmd grok)" == 'grok login --oauth' ]]

# A failing provider-owned status probe must override a stale auth file.
ln -sf /bin/false "$fakebin/codex"
codex_state="$(cockpit_auth_state codex || true)"
[[ "$codex_state" == auth-needed ]]
ln -sf /bin/true "$fakebin/codex"

# Grok has no status subcommand; expired or malformed cache records are not ready.
cat >"$HOME/.grok/auth.json" <<'EOF'
{"session":{"auth_mode":"oidc","key":"access-key","refresh_token":"refresh-token","expires_at":"2000-01-01T00:00:00Z"}}
EOF
grok_state="$(cockpit_auth_state grok || true)"
[[ "$grok_state" == auth-needed ]]
printf '%s\n' '{not-json' >"$HOME/.grok/auth.json"
grok_state="$(cockpit_auth_state grok || true)"
[[ "$grok_state" == auth-needed ]]

printf '%s\n' 'Auth probe regression: PASS'
