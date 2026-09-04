#!/usr/bin/env bash
# BENCH watcher in an isolated named window; Agent pane must not respawn.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-bench-window.XXXXXX)"
session=cockpit-bench-test
bench_home="$test_root/bench"
tmux_root="$test_root/tmux"

cleanup() {
  tmux kill-session -t "$session" 2>/dev/null || true
  rm -rf "$test_root"
}
trap cleanup EXIT

cp -a "$repo_root/tests/fixtures/bench/." "$bench_home/"
mkdir -p "$tmux_root"

export COCKPIT_BENCH_HOME="$bench_home"
export TMUX_TMPDIR="$tmux_root"
export PATH="$repo_root/bin:/usr/bin:/bin"
unset TMUX TMUX_PANE

tmux new-session -d -s "$session" -n AGENT -c "$test_root" 'exec sleep 120'
tmux set-option -p -t "$session:AGENT" @cockpit_role runtime
tmux new-window -d -t "$session:" -n BENCH -c "$test_root" \
  "exec cockpit-bench"
tmux set-option -p -t "$session:BENCH" @cockpit_role bench

bench_pane="$(tmux display-message -p -t "$session:BENCH" '#{pane_id}')"
bench_role="$(tmux display-message -p -t "$bench_pane" '#{@cockpit_role}')"
[[ "$bench_role" == "bench" ]]

agent_pid="$(tmux display-message -p -t "$session:AGENT" '#{pane_pid}')"
sleep 1
agent_pid_after="$(tmux display-message -p -t "$session:AGENT" '#{pane_pid}')"
[[ "$agent_pid" == "$agent_pid_after" ]]

check_output="$(COCKPIT_BENCH_HOME="$bench_home" bench check)"
grep -q '^status=ok$' <<<"$check_output"

printf '%s\n' 'Bench window regression: PASS'
