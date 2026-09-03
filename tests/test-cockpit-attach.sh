#!/usr/bin/env bash
# Bare cockpit must attach an existing session without a project cwd.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-attach.XXXXXX)"
test_home="$test_root/home"
install_tmux_root="$test_root/install-tmux"
mkdir -p "$test_home"

cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT

export HOME="$test_home"
export TMUX_TMPDIR="$install_tmux_root"
export PATH="$test_home/.local/bin:$repo_root/bin:/usr/bin:/bin"
unset TMUX TMUX_PANE

tmux_test() {
  env -u TMUX -u TMUX_PANE tmux "$@"
}

tmux_test -f /dev/null new-session -d -s cockpit -n AGENT 'exec sleep 120'

output="$(COCKPIT_SKIP_GATE=1 "$repo_root/bin/cockpit-main" </dev/null 2>&1 || true)"
grep -q 'session cockpit already running' <<<"$output"
grep -q 'cockpit agent' <<<"$output"

reject_output="$(COCKPIT_SKIP_GATE=1 "$repo_root/bin/cockpit-main" /tmp 2>&1 || true)"
grep -q 'not a project directory' <<<"$reject_output"

printf '%s\n' 'Cockpit attach regression: PASS'
