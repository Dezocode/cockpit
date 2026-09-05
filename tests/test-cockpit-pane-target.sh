#!/usr/bin/env bash
# Session bootstrap must not use tmux 3.5a-invalid pane indexes like :1.1.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-pane.XXXXXX)"
session=cockpit-pane-test

cleanup() {
  tmux kill-session -t "$session" 2>/dev/null || true
  rm -rf "$test_root"
}
trap cleanup EXIT

tmux new-session -d -s "$session" -n AGENT -c "$test_root" 'exec sleep 120'
tmux set-option -p -t "$session:AGENT" @cockpit_role runtime
tmux new-window -d -t "$session:" -n FILES -c "$test_root" 'exec sleep 120'
tmux set-option -p -t "$session:FILES" @cockpit_role files
tmux new-window -d -t "$session:" -n PRS -c "$test_root" 'exec sleep 120'
tmux set-option -p -t "$session:PRS" @cockpit_role prs

# shellcheck source=../bin/cockpit-lib
source "$repo_root/bin/cockpit-lib"
cockpit_select_agent_pane "$session"

active_window="$(tmux display-message -p -t "$session:" '#{window_name}')"
active_role="$(tmux display-message -p -t "$session:" '#{@cockpit_role}')"
[[ "$active_window" == "AGENT" ]]
[[ "$active_role" == "runtime" ]]

windows="$(tmux list-windows -t "$session" -F '#{window_name}' | tr '\n' ' ')"
grep -q AGENT <<<"$windows"
grep -q FILES <<<"$windows"
grep -q PRS <<<"$windows"

printf '%s\n' 'Cockpit pane targeting regression: PASS'
