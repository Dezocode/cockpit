#!/usr/bin/env bash
# PREP-only: MEMORY watcher in an isolated pane. Session chrome routing is deferred.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-memory-window.XXXXXX)"
session=cockpit-memory-test
intercom_home="$test_root/intercom"

cleanup() {
  tmux kill-session -t "$session" 2>/dev/null || true
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$intercom_home/memory"
install -m 0644 "$repo_root/tests/fixtures/cockpit.mmd" "$intercom_home/memory/cockpit.mmd"

export COCKPIT_INTERCOM_HOME="$intercom_home"
export PATH="$repo_root/bin:/usr/bin:/bin"

tmux new-session -d -s "$session" -n AGENT -c "$test_root" 'exec sleep 120'
tmux set-option -p -t "$session:AGENT" @cockpit_role runtime
tmux new-window -d -t "$session:" -n MEMORY -c "$test_root" \
  "exec cockpit-memory-watch $test_root"
tmux set-option -p -t "$session:MEMORY" @cockpit_role memory

memory_pane="$(tmux display-message -p -t "$session:MEMORY" '#{pane_id}')"
memory_role="$(tmux display-message -p -t "$memory_pane" '#{@cockpit_role}')"
[[ "$memory_role" == "memory" ]]

agent_pid="$(tmux display-message -p -t "$session:AGENT" '#{pane_pid}')"
sleep 1
agent_pid_after="$(tmux display-message -p -t "$session:AGENT" '#{pane_pid}')"
[[ "$agent_pid" == "$agent_pid_after" ]]

check_output="$(COCKPIT_INTERCOM_HOME="$intercom_home" memory check)"
grep -q '^status=ok$' <<<"$check_output"

printf '%s\n' 'Memory window prep regression: PASS'
