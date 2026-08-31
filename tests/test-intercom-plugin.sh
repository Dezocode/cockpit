#!/usr/bin/env bash
# Intercom must fail closed without gh auth and without repo scope.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-intercom.XXXXXX)"
test_home="$test_root/home"
fakebin="$test_root/bin"
mkdir -p "$test_home/.config/cockpit" "$fakebin"

cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT

export HOME="$test_home"
export COCKPIT_AUTH_HOME="$HOME/.config/cockpit"
export COCKPIT_INTERCOM_HOME="$test_root/intercom"
export PATH="$fakebin:$repo_root/bin:/usr/bin:/bin"

cat >"$COCKPIT_AUTH_HOME/providers.conf" <<'EOF'
[github]
label=GitHub
kind=cli-oauth
check=command -v gh
auth_check=gh auth status -h github.com
login=gh auth login -h github.com -p https -w
EOF

cat >"$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${FAKE_GH_MODE:-missing}" in
  missing)
    printf 'gh: command not found\n' >&2
    exit 127
    ;;
  unsigned)
    case "$*" in
      'auth status -h github.com') exit 1 ;;
      'repo view Dezocode/intercom') exit 1 ;;
      *) exit 0 ;;
    esac
    ;;
  signed-no-repo)
    case "$*" in
      'auth status -h github.com') exit 0 ;;
      'repo view Dezocode/intercom') exit 1 ;;
      'api user --jq .login') printf 'test-user\n' ;;
      *) exit 0 ;;
    esac
    ;;
  ready)
    case "$*" in
      'auth status -h github.com') exit 0 ;;
      'repo view Dezocode/intercom') exit 0 ;;
      'api user --jq .login') printf 'test-user\n' ;;
      'repo clone Dezocode/intercom'*)
        mkdir -p "$COCKPIT_INTERCOM_HOME/.git"
        printf 'ref: refs/heads/main\n' >"$COCKPIT_INTERCOM_HOME/.git/HEAD"
        exit 0
        ;;
      *) exit 0 ;;
    esac
    ;;
  *)
    printf 'unknown fake gh mode: %s\n' "${FAKE_GH_MODE:-}" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$fakebin/gh"

intercom="$repo_root/plugins/cockpit-intercom/intercom"

export FAKE_GH_MODE=unsigned
unsigned_output="$(FAKE_GH_MODE=unsigned "$intercom" auth-check 2>&1 || true)"
grep -q '^gh_auth=needed$' <<<"$unsigned_output"
grep -q 'gh auth login -h github.com -p https -w' <<<"$unsigned_output"

export FAKE_GH_MODE=signed-no-repo
denied_output="$(FAKE_GH_MODE=signed-no-repo "$intercom" auth-check 2>&1 || true)"
grep -q '^repo_access=denied$' <<<"$denied_output"
grep -q '^repo=Dezocode/intercom$' <<<"$denied_output"

export FAKE_GH_MODE=ready
ready_output="$(FAKE_GH_MODE=ready "$intercom" auth-check 2>&1)"
grep -q '^gh_auth=ready$' <<<"$ready_output"
grep -q '^repo_access=ok$' <<<"$ready_output"

list_output="$(cockpit-plugin list)"
grep -q '^cockpit\.intercom[[:space:]]' <<<"$list_output"

check_output="$(FAKE_GH_MODE=ready "$intercom" write --id demo --message marker --check 2>&1)"
grep -q '^mode=check$' <<<"$check_output"
grep -q '^peer=peers/demo.md$' <<<"$check_output"

invalid_status="$(FAKE_GH_MODE=ready "$intercom" write --id '../evil' --message marker --check 2>&1 || true)"
grep -qi 'invalid peer id' <<<"$invalid_status"

printf '%s\n' 'Intercom plugin regression: PASS'
