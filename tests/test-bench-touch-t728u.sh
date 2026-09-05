#!/usr/bin/env bash
# t728u-next touch proof — on_mouse handler via nvim RPC (remote-send j/Enter ≠ touch PASS).
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-bench-touch-t728u.XXXXXX)"
mirror="$test_root/proctor"
runtime_dir="$test_root/runtime"
socket_root="$test_root/tmux"
session="cockpit-bench-touch-t728u"
socket="$test_root/cockpit-bench-touch.sock"
fixture_root="$repo_root/tests/fixtures/bench"
db="$mirror/db/runs.sqlite"

fail() {
  printf 'Bench touch t728u FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$socket_root" tmux -S "$socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$test_root"
}
trap cleanup EXIT

command -v nvim >/dev/null 2>&1 || command -v "$repo_root/.local/bin/nvim" >/dev/null 2>&1 ||
  fail 'nvim required for touch proof'

tmux_test() {
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$socket_root" tmux -S "$socket" "$@"
}

bench_nvim_sock() {
  local pane_pid=$1
  pgrep -P "$pane_pid" -a nvim 2>/dev/null |
    sed -n 's/.*--listen \([^ ]*\).*/\1/p' |
    head -n 1
}

touch_probe() {
  local sock=$1 line0=$2 col=$3
  nvim --server "$sock" --remote-send "<Cmd>lua vim.g.CockpitBench.touch_probe(${line0}, ${col})<CR>" >/dev/null
}

mkdir -p "$mirror/db" "$runtime_dir" "$socket_root" "$test_root/home"
install -m 0644 "$fixture_root/MODELS_INDEX.csv" "$mirror/MODELS_INDEX.csv"
install -m 0644 "$fixture_root/CROSSREF_LINKS.csv" "$mirror/CROSSREF_LINKS.csv"

sqlite3 "$db" <<'SQL'
PRAGMA foreign_keys = ON;
CREATE TABLE models (model_id TEXT PRIMARY KEY, agent_class TEXT NOT NULL, home_path TEXT NOT NULL, notes TEXT);
CREATE TABLE runs (run_id TEXT PRIMARY KEY, model_id TEXT NOT NULL REFERENCES models(model_id), role TEXT, campaign TEXT, disposition TEXT, scored_at TEXT, payload_json TEXT NOT NULL);
CREATE TABLE run_links (from_run_id TEXT NOT NULL, to_run_id TEXT NOT NULL, link_kind TEXT NOT NULL, PRIMARY KEY (from_run_id, to_run_id, link_kind));
INSERT INTO models VALUES
  ('gpt-5.6-sol', 'frontier_subscription', 'bench/codex/sol', 'peer fixture'),
  ('local/Qwen3.5-4B', 'local', 'bench/local', 'local fixture');
INSERT INTO runs VALUES
  ('run-sol-001', 'gpt-5.6-sol', 'sol_admin', 'sol-v1.7.1', 'incomplete', '2026-09-04T19:54:34Z', '{}'),
  ('run-local-001', 'local/Qwen3.5-4B', 'experiment_worker', 'sol-v1.7.1', 'repair', '2026-09-04T19:54:35Z', '{}');
SQL

tmux_test kill-server >/dev/null 2>&1 || true
tmux_test -f /dev/null new-session -d -s "$session" -x 220 -y 40 -n BENCH -c "$repo_root" \
  "export TERM=xterm-256color; \
export PATH=$repo_root/.local/bin:$repo_root/bin:${HOME}/.local/bin:/usr/bin:/bin; \
export HOME=$test_root/home; \
export COCKPIT_PROCTOR_HOME=$mirror; \
export XDG_RUNTIME_DIR=$runtime_dir; \
exec $repo_root/bin/cockpit-bench"

tries=0
while ((tries < 80)); do
  cap="$(tmux_test capture-pane -p -t "$session:BENCH" -S -40 2>/dev/null || true)"
  if grep -Fq 'Models' <<<"$cap" && grep -Fq 'gpt-5.6-sol' <<<"$cap"; then
    break
  fi
  sleep 0.05
  tries=$((tries + 1))
done
((tries < 80)) || fail 'BENCH pane did not render Models column'

before="$(tmux_test capture-pane -p -t "$session:BENCH" -S -40)"
grep -Fq '> gpt-5.6-sol' <<<"$before" || fail 'expected gpt-5.6-sol selected before touch drill'

pane_pid="$(tmux_test display-message -p -t "$session:BENCH" '#{pane_pid}')"
nvim_sock="$(bench_nvim_sock "$pane_pid")"
[[ -n "$nvim_sock" && -S "$nvim_sock" ]] || fail 'could not resolve BENCH nvim listen socket for touch probe'

# Line 3 is local/Qwen in column 0 (0-based line index); double-tap selects then drills L1→L2.
touch_probe "$nvim_sock" 3 0
sleep 0.1
touch_probe "$nvim_sock" 3 0
sleep 0.15

after="$(tmux_test capture-pane -p -t "$session:BENCH" -S -40)"
grep -Fq 'Runs — local/Qwen3.5-4B' <<<"$after" ||
  fail 'touch_probe on_mouse did not drill L1→L2 (keyboard send-keys is not touch proof)'
grep -Fq '> gpt-5.6-sol' <<<"$after" &&
  fail 'touch_probe left focus on gpt model after drill (on_mouse did not advance)'

printf '%s\n' 'Bench touch t728u on_mouse contract: PASS'
