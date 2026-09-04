#!/usr/bin/env bash
# BENCH Proctor SQLite contract, plugin dispatch, and isolated ghui drill.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-bench-test.XXXXXX)"
mirror="$test_root/proctor"
missing="$test_root/missing-proctor"
box="$test_root/box-truth"
project="$test_root/project"
runtime_dir="$test_root/runtime"
socket_root="$test_root/tmux"
session="cockpit-bench-test-$$"
socket="$test_root/cockpit-bench-$RANDOM-$$.sock"
fixture_root="$repo_root/tests/fixtures/bench"
db="$mirror/db/runs.sqlite"
pane_pid=''

cleanup() {
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$socket_root" tmux -S "$socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$test_root"
}
trap cleanup EXIT

fail() {
  printf 'BENCH regression FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'BENCH regression OK: %s\n' "$*"
}

tmux_test() {
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$socket_root" tmux -S "$socket" "$@"
}

bench() {
  env HOME="$test_root/home" XDG_RUNTIME_DIR="$runtime_dir" \
    PATH="$repo_root/.local/bin:$repo_root/bin:/usr/bin:/bin" \
    "$repo_root/bin/cockpit-bench" "$@"
}

mkdir -p "$mirror/db" "$missing" "$box/db" "$project" "$runtime_dir" \
  "$socket_root" "$test_root/home"
install -m 0644 "$fixture_root/MODELS_INDEX.csv" "$mirror/MODELS_INDEX.csv"
install -m 0644 "$fixture_root/CROSSREF_LINKS.csv" "$mirror/CROSSREF_LINKS.csv"

sqlite3 "$db" <<'SQL'
PRAGMA foreign_keys = ON;
CREATE TABLE models (
  model_id TEXT PRIMARY KEY,
  agent_class TEXT NOT NULL,
  home_path TEXT NOT NULL,
  notes TEXT
);
CREATE TABLE runs (
  run_id TEXT PRIMARY KEY,
  model_id TEXT NOT NULL REFERENCES models(model_id),
  role TEXT,
  campaign TEXT,
  disposition TEXT,
  scored_at TEXT,
  payload_json TEXT NOT NULL
);
CREATE TABLE run_links (
  from_run_id TEXT NOT NULL,
  to_run_id TEXT NOT NULL,
  link_kind TEXT NOT NULL,
  PRIMARY KEY (from_run_id, to_run_id, link_kind)
);
INSERT INTO models VALUES
  ('local/Qwen3.5-4B', 'local', 'bench/local', 'local fixture'),
  ('gpt-5.6-sol', 'frontier_subscription', 'bench/codex/sol', 'peer fixture');
INSERT INTO runs VALUES
  ('run-local-001', 'local/Qwen3.5-4B', 'experiment_worker', 'sol-v1.7.1', 'repair', '2026-09-04T19:54:34Z', '{"agent_class":"local","node":"deck","administered_by":"sol"}'),
  ('run-sol-001', 'gpt-5.6-sol', 'sol_admin', 'sol-v1.7.1', 'incomplete', '2026-09-04T19:54:34Z', '{"agent_class":"frontier_subscription","node":"deck-sol"}');
INSERT INTO run_links VALUES ('run-local-001', 'run-sol-001', 'sol_session_ref');
SQL

valid_check="$(COCKPIT_PROCTOR_HOME="$mirror" bench check)"
grep -Fxq 'status=ok' <<<"$valid_check" || fail 'valid Proctor mirror did not validate'
grep -Fxq 'source=intercom' <<<"$valid_check" || fail 'mirror source was not identified as intercom'
grep -Fxq 'model_count=2' <<<"$valid_check" || fail 'model count is not receipt-backed'
grep -Fxq 'run_count=2' <<<"$valid_check" || fail 'run count is not receipt-backed'
grep -Fxq 'backlink_count=1' <<<"$valid_check" || fail 'backlink count is not receipt-backed'

mkdir -p "$test_root/home/intercom/proctor"
cp -a "$mirror/." "$test_root/home/intercom/proctor/"
default_check="$(
  unset COCKPIT_PROCTOR_HOME
  bench check
)"
grep -Fxq 'status=ok' <<<"$default_check" || fail 'default ~/intercom/proctor mirror was not preferred'

path_output="$(COCKPIT_PROCTOR_HOME="$mirror" bench path)"
grep -Fxq "root=$mirror" <<<"$path_output" || fail 'path did not expose the resolved mirror'
grep -Fxq "db=$db" <<<"$path_output" || fail 'path did not expose runs.sqlite'
grep -Fxq "models_index=$mirror/MODELS_INDEX.csv" <<<"$path_output" || fail 'path did not expose MODELS_INDEX.csv'

models_output="$(COCKPIT_PROCTOR_HOME="$mirror" bench models)"
grep -Fxq $'gpt-5.6-sol\tfrontier_subscription' <<<"$models_output" ||
  fail 'L1 model output omitted the stored frontier agent_class badge'
grep -Fxq $'local/Qwen3.5-4B\tlocal' <<<"$models_output" ||
  fail 'L1 model output omitted the stored local agent_class badge'

runs_output="$(COCKPIT_PROCTOR_HOME="$mirror" bench runs 'local/Qwen3.5-4B')"
grep -Fq $'run-local-001\tlocal\texperiment_worker\trepair' <<<"$runs_output" ||
  fail 'L2 run output did not come from the SQLite mirror'
absent_runs="$(COCKPIT_PROCTOR_HOME="$mirror" bench runs 'missing/model')"
grep -Fxq 'ABSENT' <<<"$absent_runs" || fail 'missing L2 model did not fail closed'

show_output="$(COCKPIT_PROCTOR_HOME="$mirror" bench show-run run-local-001)"
grep -Fq $'run-local-001\tlocal/Qwen3.5-4B\tlocal\texperiment_worker\tsol-v1.7.1\trepair' <<<"$show_output" ||
  fail 'L3 run detail did not expose the receipt row'
grep -Fq $'backlink\trun-sol-001\tgpt-5.6-sol\tfrontier_subscription\tsol_session_ref' <<<"$show_output" ||
  fail 'L3 backlink did not expose its peer run and link kind'
absent_run="$(COCKPIT_PROCTOR_HOME="$mirror" bench show-run missing-run)"
grep -Fxq 'ABSENT' <<<"$absent_run" || fail 'missing L3 run did not fail closed'

bad_schema="$test_root/bad-schema"
mkdir -p "$bad_schema/db"
install -m 0644 "$fixture_root/MODELS_INDEX.csv" "$bad_schema/MODELS_INDEX.csv"
sqlite3 "$bad_schema/db/runs.sqlite" 'CREATE TABLE models (model_id TEXT);'
if COCKPIT_PROCTOR_HOME="$bad_schema" bench check >"$test_root/bad-schema.log" 2>&1; then
  fail 'incomplete SQLite schema was accepted'
fi
grep -Fq 'BENCH unavailable' "$test_root/bad-schema.log" || fail 'schema failure was not explicit'

bad_links="$test_root/bad-links"
mkdir -p "$bad_links/db"
cp "$mirror/db/runs.sqlite" "$bad_links/db/runs.sqlite"
install -m 0644 "$mirror/MODELS_INDEX.csv" "$bad_links/MODELS_INDEX.csv"
sqlite3 "$bad_links/db/runs.sqlite" \
  "INSERT INTO run_links VALUES ('run-local-001', 'missing-peer', 'sol_session_ref');"
if COCKPIT_PROCTOR_HOME="$bad_links" bench check >"$test_root/bad-links.log" 2>&1; then
  fail 'dangling backlink was accepted'
fi
grep -Fq 'BENCH unavailable' "$test_root/bad-links.log" || fail 'dangling backlink was not explicit'

cp -a "$mirror/." "$box/"
missing_log="$test_root/missing.log"
if COCKPIT_PROCTOR_HOME="$missing" COCKPIT_BENCH_HOME="$box" bench --once >"$missing_log" 2>&1; then
  fail 'missing Proctor mirror or Box truth was accepted'
fi
grep -Fq 'BENCH unavailable' "$missing_log" || fail 'missing mirror had no fail-closed state'
if grep -Fq 'run-local-001' "$missing_log" || grep -Fq 'local/Qwen3.5-4B' "$missing_log"; then
  fail 'missing mirror produced an invented row'
fi

mkdir -p "$project/db"
cp "$mirror/db/runs.sqlite" "$project/db/runs.sqlite"
if (
  cd -- "$project"
  COCKPIT_PROCTOR_HOME="$missing" COCKPIT_BENCH_HOME="$box" bench check
) >"$test_root/project-fallback.log" 2>&1; then
  fail 'project or Box data bypassed the Proctor-only source contract'
fi
grep -Fq 'BENCH unavailable' "$test_root/project-fallback.log" ||
  fail 'project fallback did not fail closed'

plugin_env=(COCKPIT_CONFIG_HOME="$test_root/config" COCKPIT_PROCTOR_HOME="$mirror")
plugin_rows="$(env "${plugin_env[@]}" "$repo_root/bin/cockpit-plugin" list)"
grep -Eq '^cockpit\.bench[[:space:]]+type=cockpit[[:space:]]+version=' <<<"$plugin_rows" ||
  fail 'cockpit.bench is missing from the native registry'
plugin_check="$(env "${plugin_env[@]}" "$repo_root/bin/cockpit-plugin" run cockpit.bench check)"
grep -Fxq 'status=ok' <<<"$plugin_check" || fail 'native plugin dispatch did not reach BENCH'
standalone_check="$(env "${plugin_env[@]}" PATH="$repo_root/bin:/usr/bin:/bin" "$repo_root/bin/bench" check)"
grep -Fxq 'status=ok' <<<"$standalone_check" || fail 'standalone bench command did not dispatch'

grep -Fq 'new-window -d -t "$session:" -n BENCH' "$repo_root/bin/cockpit-main"
grep -Fq 'tag "$session:BENCH" BENCH bench' "$repo_root/bin/cockpit-main"
grep -Fq 'bench|BENCH' "$repo_root/bin/cockpit-touch"
grep -Fq 'bench:BENCH' "$repo_root/bin/cockpit-adapt"
grep -Fq 'bench:9' "$repo_root/bin/cockpit-adapt"
grep -Fq 'ensure_bench' "$repo_root/bin/cockpit-reload-views"
grep -Fq 'BENCH|bench' "$repo_root/bin/cockpit-wake"
grep -Fq 'cockpit.bench' "$repo_root/plugins/cockpit-bench/plugin.conf"
if rg -n -i '/workspace/bench|COCKPIT_BENCH_HOME|(^|[[:space:]])ssh([[:space:]]|$)|tmux[[:space:]]+attach|(^|[[:space:]])(UPDATE|INSERT|DELETE)([[:space:]]|$)' \
  "$repo_root/bin/cockpit-bench" "$repo_root/plugins/cockpit-bench/bench"; then
  fail 'BENCH surface contains a Box, remote-session, or write path'
fi
grep -Fq 'COCKPIT_NVIM_BENCH_LAYOUT_INIT' "$repo_root/bin/cockpit-bench" ||
  fail 'BENCH does not use the canonized nvim layout path'
grep -Fq 'exec nvim' "$repo_root/bin/cockpit-bench" ||
  fail 'BENCH does not exec nvim like the FILES surface family'
layout="$repo_root/stage/nvim/lua/config/cockpit-bench.lua"
grep -Fq 'cockpit · MEMORY  COMPUTERS  MODELS  BENCH  FILES  PRS' "$layout" ||
  fail 'approved top-left ghui chrome is missing'
grep -Fq 'BENCH  ghui  read-only' "$layout" ||
  fail 'approved top-right ghui chrome is missing'
grep -Fq 'Run + backlinks' "$layout" || fail 'L3 column renderer is missing'
grep -Fq 'COCKPIT_NVIM_FILES_LAYOUT_INIT' "$repo_root/bin/cockpit-files" ||
  fail 'FILES nvim layout path regressed'
grep -Fq 'exec nvim' "$repo_root/bin/cockpit-files" ||
  fail 'FILES nvim surface regressed'
grep -Fq 'wanted_width' "$repo_root/stage/nvim/lua/config/cockpit-files.lua" ||
  fail 'FILES neo-tree sizing polish regressed'
pass 'source contract, plugin registry, ghui shape, and FILES surface'

source_hash="$(sha256sum "$mirror/db/runs.sqlite" "$mirror/MODELS_INDEX.csv" "$mirror/CROSSREF_LINKS.csv")"
tmux_test -f /dev/null new-session -d -s "$session" -x 220 -y 40 -n BENCH -c "$repo_root" \
  "export PATH=$(printf '%q' "$repo_root/.local/bin:$repo_root/bin:/usr/bin:/bin"); \
export HOME=$(printf '%q' "$test_root/home"); \
export COCKPIT_PROCTOR_HOME=$(printf '%q' "$mirror"); \
export XDG_RUNTIME_DIR=$(printf '%q' "$runtime_dir"); \
exec $(printf '%q' "$repo_root/bin/cockpit-bench")"
for _ in {1..40}; do
  pane_pid="$(tmux_test display-message -p -t "$session:BENCH" '#{pane_pid}' 2>/dev/null || true)"
  [[ -n "$pane_pid" ]] && break
  sleep 0.05
done
[[ -n "$pane_pid" ]] || fail 'isolated BENCH tmux pane did not become ready'

capture() {
  tmux_test capture-pane -p -t "$session:BENCH" -S -120
}

wait_for() {
  local needle=$1 tries=0 cap
  while ((tries < 100)); do
    cap="$(capture)"
    if grep -Fq "$needle" <<<"$cap"; then
      printf '%s\n' "$cap"
      return 0
    fi
    sleep 0.05
    tries=$((tries + 1))
  done
  return 1
}

wait_for 'Models' >/dev/null || fail 'isolated BENCH pane did not render L1'
tmux_test send-keys -t "$session:BENCH" j
sleep 0.1
tmux_test send-keys -t "$session:BENCH" Enter
sleep 0.1
wait_for 'Runs — local/Qwen3.5-4B' >/dev/null || fail 'Enter did not open L2 runs'
tmux_test send-keys -t "$session:BENCH" Enter
sleep 0.1
detail="$(wait_for 'Run + backlinks')" || fail 'Enter did not open L3 run detail'
grep -Fq 'run-local-001' <<<"$detail" || fail 'L3 detail did not show the selected run'
grep -Fq 'sol_session_ref' <<<"$detail" || fail 'L3 detail did not show the backlink chip'

tmux_test send-keys -t "$session:BENCH" Enter
sleep 0.1
followed="$(wait_for 'run-sol-001')" || fail 'Enter on backlink did not jump to the peer run'
grep -Fq 'gpt-5.6-sol' <<<"$followed" || fail 'backlink jump did not select the peer model'

tmux_test send-keys -t "$session:BENCH" Escape
sleep 0.1
popped="$(wait_for 'run-local-001')" || fail 'Esc did not pop backlink history'
grep -Fq 'sol_session_ref' <<<"$popped" || fail 'Esc did not restore the original backlink detail'

[[ "$(tmux_test display-message -p -t "$session:BENCH" '#{pane_pid}')" == "$pane_pid" ]] ||
  fail 'navigation respawned the BENCH pane'
[[ "$source_hash" == "$(sha256sum "$mirror/db/runs.sqlite" "$mirror/MODELS_INDEX.csv" "$mirror/CROSSREF_LINKS.csv")" ]] ||
  fail 'BENCH changed the Proctor mirror'
pass 'isolated tmux L1/L2/L3 backlink drill with Esc history'

printf '%s\n' 'BENCH regression: PASS'
