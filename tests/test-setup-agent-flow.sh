#!/usr/bin/env bash
# SETUP confirmation path for a provider-targeted .agent file.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-setup-agent.XXXXXX)"
test_home="$test_root/home"
project="$test_root/project"
fakebin="$test_root/bin"
mkdir -p "$test_home/.config/cockpit/skills.d" "$project" "$fakebin"
cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT

export HOME="$test_home"
export COCKPIT_AUTH_HOME="$HOME/.config/cockpit"
export COCKPIT_PROFILE_FILE="$COCKPIT_AUTH_HOME/profile.conf"
export COCKPIT_SKILLS_DIR="$COCKPIT_AUTH_HOME/skills.d"
export COCKPIT_SESSION=cockpit-setup-agent-test
export PATH="$fakebin:$repo_root/bin:/usr/bin:/bin"
unset TMUX TMUX_PANE

cat >"$COCKPIT_AUTH_HOME/providers.conf" <<'EOF'
[codex]
label=Codex
kind=runtime
check=command -v codex
probe=codex-login
start=codex
agent_paths=.agent
EOF
cat >"$COCKPIT_AUTH_HOME/profile.conf" <<'EOF'
[profile]
enabled=1
skills_dir=~/.config/cockpit/skills.d
EOF
cat >"$COCKPIT_AUTH_HOME/skills.d/cockpit.md" <<'EOF'
Keep Cockpit updates small and reversible.
EOF
cat >"$project/.agent" <<'EOF'
# Existing provider instructions

Do not remove this text.
EOF
cat >"$fakebin/codex" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  'login status') exit 0 ;;
  'plugin list --available --json') printf '%s\n' '{"installed":[],"available":[]}' ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$fakebin/codex"

output="$(cd "$project" && printf 'y\nx\nq\n' | timeout 8s "$repo_root/bin/cockpit-setup" profile 2>&1)"
grep -q 'COCKPIT PROFILE' <<<"$output"
grep -q 'Profile skills synced' <<<"$output"
grep -Fq 'cockpit-profile:begin' "$project/.agent"
grep -Fq 'cockpit-profile:skill:cockpit' "$project/.agent"
grep -Fq 'Do not remove this text.' "$project/.agent"

printf '%s\n' 'SETUP agent profile regression: PASS'
