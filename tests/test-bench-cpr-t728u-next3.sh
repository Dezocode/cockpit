#!/usr/bin/env bash
# t728u-next3 live CPR — multi-chip separation + omarchy-flat text capture (not mock).
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-bench-cpr-next3.XXXXXX)"
mirror="$test_root/proctor"
runtime_dir="$test_root/runtime"
socket_root="$test_root/tmux"
session="cockpit-bench-cpr-next3"
socket="$test_root/cockpit-bench-cpr-next3.sock"
fixture_root="$repo_root/tests/fixtures/bench"
db="$mirror/db/runs.sqlite"
proof_dir="$repo_root/proofs"
stamp="$(date -u +%Y%m%d-%H%M%S)"
proof_txt="$proof_dir/bench-bar-t728u-next3-live-${stamp}.txt"

fail() {
  printf 'Bench CPR next3 FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$socket_root" tmux -S "$socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$test_root"
}
trap cleanup EXIT

command -v nvim >/dev/null 2>&1 || command -v "$repo_root/.local/bin/nvim" >/dev/null 2>&1 ||
  fail 'nvim required for live CPR proof'

tmux_test() {
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$socket_root" tmux -S "$socket" "$@"
}

mkdir -p "$mirror/db" "$runtime_dir" "$socket_root" "$test_root/home" "$proof_dir"
install -m 0644 "$fixture_root/MODELS_INDEX.csv" "$mirror/MODELS_INDEX.csv"
install -m 0644 "$fixture_root/CROSSREF_LINKS.csv" "$mirror/CROSSREF_LINKS.csv"

sqlite3 "$db" <<'SQL'
PRAGMA foreign_keys = ON;
CREATE TABLE models (model_id TEXT PRIMARY KEY, agent_class TEXT NOT NULL, home_path TEXT NOT NULL, notes TEXT);
CREATE TABLE runs (run_id TEXT PRIMARY KEY, model_id TEXT NOT NULL REFERENCES models(model_id), role TEXT, campaign TEXT, disposition TEXT, scored_at TEXT, payload_json TEXT NOT NULL);
CREATE TABLE run_links (from_run_id TEXT NOT NULL, to_run_id TEXT NOT NULL, link_kind TEXT NOT NULL, PRIMARY KEY (from_run_id, to_run_id, link_kind));
INSERT INTO models VALUES
  ('gpt-5.6-sol', 'frontier_subscription', 'bench/codex/sol', 'peer fixture'),
  ('gpt-5.6-luna', 'frontier_subscription', 'bench/codex/luna', 'peer fixture'),
  ('local/Qwen3.5-4B', 'local', 'bench/local', 'local fixture');
INSERT INTO runs VALUES
  ('run-sol-001', 'gpt-5.6-sol', 'sol_admin', 'sol-v1.7.1', 'incomplete', '2026-09-04T19:54:34Z', '{}'),
  ('run-local-001', 'local/Qwen3.5-4B', 'experiment_worker', 'sol-v1.7.1', 'repair', '2026-09-04T19:54:35Z', '{}'),
  ('parent-run-001', 'gpt-5.6-sol', 'sol_admin', 'sol-v1.7.1', 'incomplete', '2026-09-04T20:00:00Z', '{}'),
  ('parent-run-001::abc1', 'gpt-5.6-sol', 'experiment_worker', 'sol-v1.7.1', 'incomplete', '2026-09-04T20:01:00Z', '{}');
INSERT INTO run_links VALUES
  ('parent-run-001', 'run-sol-001', 'worker_deck_run'),
  ('parent-run-001', 'run-local-001', 'worker_deck_run');
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
cap=''
while ((tries < 100)); do
  cap="$(tmux_test capture-pane -p -t "$session:BENCH" -S -80 2>/dev/null || true)"
  if grep -Fq 'Models' <<<"$cap" && grep -Fq 'Run + backlinks' <<<"$cap"; then
    break
  fi
  sleep 0.05
  tries=$((tries + 1))
done
((tries < 100)) || fail 'BENCH pane did not render Miller columns'

# Drill to parent-run-001 on gpt-5.6-sol for multi-chip backlinks.
tmux_test send-keys -t "$session:BENCH" j
sleep 0.1
tmux_test send-keys -t "$session:BENCH" Enter
sleep 0.1
tmux_test send-keys -t "$session:BENCH" j
sleep 0.1
tmux_test send-keys -t "$session:BENCH" Enter
sleep 0.15

cap="$(tmux_test capture-pane -p -t "$session:BENCH" -S -80)"
printf '%s\n' "$cap" >"$proof_txt"

grep -Fq 'Backlinks (Enter → jump)' <<<"$cap" || fail 'CPR missing backlinks header'
grep -Fc 'worker_deck_run' <<<"$cap" | grep -qx '2' ||
  fail 'CPR must show 2 separate worker_deck_run chip labels (not one packed box)'

# N chips: blank pane row(s) must sit between the two chip run_id lines.
first_rid_line="$(grep -n 'run-local-001' <<<"$cap" | head -n1 | cut -d: -f1)"
second_label_line="$(grep -n 'worker_deck_run' <<<"$cap" | tail -n1 | cut -d: -f1)"
((second_label_line > first_rid_line + 1)) ||
  fail 'multi-chip CPR lacks spacer row between chip boxes (packed strip)'

grep -Fq 't524u ghui' <<<"$cap" || fail 'CPR missing single clean footer'
grep -Eq '\+---|^\s*\|' <<<"$cap" &&
  fail 'CPR introduced ASCII box borders'

proof_hash="$(sha256sum "$proof_txt" | awk '{print $1}')"
prior_next2='2dce0af47ca96aafe8f4aef2179876677cd383b16cbccded4da7b97a092401bf'
[[ "$proof_hash" != "$prior_next2" ]] ||
  fail "next3 CPR sha256 must differ from next2 local CPR ($prior_next2)"

printf '%s\n' 'Bench CPR next3 live capture: PASS'
printf 'cpr_path=%s\n' "$proof_txt"
printf 'cpr_sha256=%s\n' "$proof_hash"
printf 'multi_chip_count=2\n'
