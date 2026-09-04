#!/usr/bin/env bash
# COMPUTERS watcher in an isolated named window; Agent pane must not respawn.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-computers-window.XXXXXX)"
session=cockpit-computers-test
intercom_home="$test_root/intercom"
tmux_root="$test_root/tmux"

cleanup() {
  tmux kill-session -t "$session" 2>/dev/null || true
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$intercom_home/models"
install -m 0644 "$repo_root/tests/fixtures/deck.json" "$intercom_home/models/deck.json"
mkdir -p "$tmux_root"

export COCKPIT_INTERCOM_HOME="$intercom_home"
export TMUX_TMPDIR="$tmux_root"
export PATH="$repo_root/bin:/usr/bin:/bin"
unset TMUX TMUX_PANE

tmux new-session -d -s "$session" -n AGENT -c "$test_root" 'exec sleep 120'
tmux set-option -p -t "$session:AGENT" @cockpit_role runtime
tmux new-window -d -t "$session:" -n COMPUTERS -c "$test_root" \
  "exec cockpit-computers"
tmux set-option -p -t "$session:COMPUTERS" @cockpit_role computers

computers_pane="$(tmux display-message -p -t "$session:COMPUTERS" '#{pane_id}')"
computers_role="$(tmux display-message -p -t "$computers_pane" '#{@cockpit_role}')"
[[ "$computers_role" == "computers" ]]

agent_pid="$(tmux display-message -p -t "$session:AGENT" '#{pane_pid}')"
sleep 1
agent_pid_after="$(tmux display-message -p -t "$session:AGENT" '#{pane_pid}')"
[[ "$agent_pid" == "$agent_pid_after" ]]

check_output="$(COCKPIT_INTERCOM_HOME="$intercom_home" computers check)"
grep -q '^status=ok$' <<<"$check_output"

printf '%s\n' 'Computers window prep regression: PASS'
