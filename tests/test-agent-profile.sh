#!/usr/bin/env bash
# Provider-aware .codex/.agent detection and confirmed profile sync.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-agent-profile.XXXXXX)"
test_home="$test_root/home"
project="$test_root/project"
mkdir -p "$test_home/.config/cockpit/skills.d" "$project/.codex"
cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT

export HOME="$test_home"
export COCKPIT_AUTH_HOME="$HOME/.config/cockpit"
export COCKPIT_PROFILE_FILE="$COCKPIT_AUTH_HOME/profile.conf"
export COCKPIT_SKILLS_DIR="$COCKPIT_AUTH_HOME/skills.d"
export PATH="$repo_root/bin:/usr/bin:/bin"

cat >"$COCKPIT_AUTH_HOME/providers.conf" <<'EOF'
[codex]
label=Codex
kind=runtime
agent_paths=.codex/AGENTS.md,.agent,AGENTS.md
EOF
cat >"$COCKPIT_AUTH_HOME/profile.conf" <<'EOF'
[profile]
enabled=1
skills_dir=~/.config/cockpit/skills.d
EOF
cat >"$COCKPIT_AUTH_HOME/skills.d/safe-edits.md" <<'EOF'
Prefer small, reversible edits.
Preserve user-authored project instructions.
EOF
cat >"$COCKPIT_AUTH_HOME/skills.d/review.md" <<'EOF'
Run focused verification after changes.
EOF
cat >"$project/.codex/AGENTS.md" <<'EOF'
# Project instructions

Keep this heading and paragraph intact.
EOF

detect="$($repo_root/bin/cockpit-agent-config detect "$project" codex)"
grep -q '^markers=.codex,.codex/AGENTS.md$' <<<"$detect"
grep -q '^target=.codex/AGENTS.md$' <<<"$detect"
grep -q '^target_state=valid$' <<<"$detect"
grep -q '^profile_skills=2$' <<<"$detect"
grep -q '^missing_profile_skills=review,safe-edits$' <<<"$detect"

before="$(<"$project/.codex/AGENTS.md")"
dry="$($repo_root/bin/cockpit-agent-config apply "$project" codex)"
grep -q '^mode=dry-run$' <<<"$dry"
[[ "$(<"$project/.codex/AGENTS.md")" == "$before" ]]

applied="$($repo_root/bin/cockpit-agent-config apply --yes "$project" codex)"
grep -q '^mode=applied$' <<<"$applied"
grep -Fq 'cockpit-profile:begin' "$project/.codex/AGENTS.md"
grep -Fq 'cockpit-profile:skill:safe-edits' "$project/.codex/AGENTS.md"
grep -Fq 'cockpit-profile:skill:review' "$project/.codex/AGENTS.md"
grep -Fq 'Keep this heading and paragraph intact.' "$project/.codex/AGENTS.md"
backup="$(awk -F= '/^backup=/{print $2}' <<<"$applied")"
[[ -f "$backup" ]]

$repo_root/bin/cockpit-agent-config validate "$project" codex >/dev/null

printf '%s\n' 'Agent profile regression: PASS'
