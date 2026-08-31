#!/usr/bin/env bash
# Session bootstrap must create a tagged MEMORY window without respawning AGENT.
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

windows="$(tmux list-windows -t "$session" -F '#{window_name}' | tr '\n' ' ')"
grep -q MEMORY <<<"$windows"

# Wake path should not crash when MEMORY watcher is present.
cockpit-wake "$session" MEMORY

agent_pid="$(tmux display-message -p -t "$session:AGENT" '#{pane_pid}')"
sleep 1
agent_pid_after="$(tmux display-message -p -t "$session:AGENT" '#{pane_pid}')"
[[ "$agent_pid" == "$agent_pid_after" ]]

touch_output="$(COCKPIT_INTERCOM_HOME="$intercom_home" cockpit-touch "$session" memory)"
[[ -z "$touch_output" || "$touch_output" == "0" ]]
active_window="$(tmux display-message -p -t "$session:" '#{window_name}')"
[[ "$active_window" == "MEMORY" ]]

printf '%s\n' 'Memory window regression: PASS'
