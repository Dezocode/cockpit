#!/usr/bin/env bash
# t728u complete card — double-chrome guard, resize proofs, winseparator durable.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
layout="$repo_root/stage/nvim/lua/config/cockpit-bench.lua"
test_root="$(mktemp -d /tmp/cockpit-bench-t728u.XXXXXX)"
mirror="$test_root/proctor"
runtime_dir="$test_root/runtime"
socket_root="$test_root/tmux"
session="cockpit-bench-t728u"
socket="$test_root/cockpit-bench-t728u.sock"
fixture_root="$repo_root/tests/fixtures/bench"
db="$mirror/db/runs.sqlite"

fail() {
  printf 'Bench t728u FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$socket_root" tmux -S "$socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$test_root"
}
trap cleanup EXIT

[[ -f "$layout" ]] || fail 'missing cockpit-bench.lua'

# Source guards (t736u pane tabs + durable winseparator)
grep -Fq 'status-position bottom' "$layout" ||
  fail 'missing tmux status-position bottom for single product chrome row'
grep -Fq "status-left ''" "$layout" ||
  fail 'missing tmux status-left blanking (stop painting COCKPIT badge as product)'
grep -Fq 'fillchars' "$layout" ||
  fail 'missing fillchars winseparator guard'
if rg -n 'vim\.o\.winseparator\s*=' "$layout"; then
  fail 'bare vim.o.winseparator present'
fi

command -v nvim >/dev/null 2>&1 || command -v "$repo_root/.local/bin/nvim" >/dev/null 2>&1 ||
  fail 'nvim required for resize proofs'

tmux_test() {
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$socket_root" tmux -S "$socket" "$@"
}

bench() {
  env HOME="$test_root/home" XDG_RUNTIME_DIR="$runtime_dir" \
    PATH="$repo_root/.local/bin:$repo_root/bin:${HOME}/.local/bin:/usr/bin:/bin" \
    COCKPIT_PROCTOR_HOME="$mirror" \
    "$repo_root/bin/cockpit-bench" "$@"
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
  ('gpt-5.6-sol', 'frontier_subscription', 'bench/codex/sol', 'peer fixture');
INSERT INTO runs VALUES
  ('run-sol-001', 'gpt-5.6-sol', 'sol_admin', 'sol-v1.7.1', 'incomplete', '2026-09-04T19:54:34Z', '{}'),
  ('run-local-001', 'gpt-5.6-sol', 'experiment_worker', 'sol-v1.7.1', 'repair', '2026-09-04T19:54:35Z', '{}'),
  ('parent-run-001', 'gpt-5.6-sol', 'sol_admin', 'sol-v1.7.1', 'incomplete', '2026-09-04T20:00:00Z', '{}'),
  ('parent-run-001::abc1', 'gpt-5.6-sol', 'experiment_worker', 'sol-v1.7.1', 'incomplete', '2026-09-04T20:01:00Z', '{}');
INSERT INTO run_links VALUES
  ('parent-run-001', 'run-sol-001', 'worker_deck_run'),
  ('parent-run-001', 'run-local-001', 'worker_deck_run');
SQL

capture_at_size() {
  local cols=$1 rows=$2
  tmux_test kill-server >/dev/null 2>&1 || true
  sleep 0.1
  tmux_test -f /dev/null new-session -d -s "$session" -x "$cols" -y "$rows" -n BENCH -c "$repo_root" \
    "export PATH=$repo_root/.local/bin:$repo_root/bin:${HOME}/.local/bin:/usr/bin:/bin; \
export HOME=$test_root/home; \
export COCKPIT_PROCTOR_HOME=$mirror; \
export XDG_RUNTIME_DIR=$runtime_dir; \
exec $repo_root/bin/cockpit-bench"
  local tries=0 cap
  while ((tries < 80)); do
    cap="$(tmux_test capture-pane -p -t "$session:BENCH" -S -80 2>/dev/null || true)"
    if grep -Fq 'Models' <<<"$cap" && grep -Fq 'Run + backlinks' <<<"$cap"; then
      printf '%s\n' "$cap"
      return 0
    fi
    sleep 0.05
    tries=$((tries + 1))
  done
  return 1
}

cap_wide="$(capture_at_size 220 40)" || fail '220x40 resize proof did not render Miller columns'
grep -Fq 'Models' <<<"$cap_wide" || fail '220x40 missing Models column'
grep -Fq 'Run + backlinks' <<<"$cap_wide" || fail '220x40 missing detail column'
grep -Fq 'worker_deck_run' <<<"$cap_wide" || fail '220x40 missing multi-chip backlink label'
grep -Fc 'worker_deck_run' <<<"$cap_wide" | grep -qx '2' ||
  fail '220x40 must show 2 separate worker_deck_run chips (not one packed box)'
first_rid_line="$(grep -n 'run-local-001' <<<"$cap_wide" | head -n1 | cut -d: -f1)"
second_label_line="$(grep -n 'worker_deck_run' <<<"$cap_wide" | tail -n1 | cut -d: -f1)"
((second_label_line > first_rid_line + 1)) ||
  fail '220x40 multi-chip CPR lacks spacer row between chip boxes'
hash_wide="$(printf '%s' "$cap_wide" | sha256sum | awk '{print $1}')"

cap_narrow="$(capture_at_size 160 32)" || fail '160x32 resize proof did not render Miller columns'
grep -Fq 'Models' <<<"$cap_narrow" || fail '160x32 missing Models column'
grep -Fq 'Run + backlinks' <<<"$cap_narrow" || fail '160x32 missing detail column'
grep -Eq '\+---|^\s*\|' <<<"$cap_narrow" &&
  fail '160x32 resize introduced ASCII box borders'
hash_narrow="$(printf '%s' "$cap_narrow" | sha256sum | awk '{print $1}')"

[[ "$hash_wide" != "$hash_narrow" ]] ||
  fail "resize CPR sha256 must differ (wide=$hash_wide narrow=$hash_narrow)"

proof_dir="$repo_root/proofs"
mkdir -p "$proof_dir"
printf '%s  %s\n' "$hash_wide" "bench-bar-t728u-resize-220x40.txt" >"$proof_dir/bench-bar-t728u-resize-220x40.sha256"
printf '%s  %s\n' "$hash_narrow" "bench-bar-t728u-resize-160x32.txt" >"$proof_dir/bench-bar-t728u-resize-160x32.sha256"

printf '%s\n' 'Bench t728u complete contract: PASS'
printf 'resize_cpr_sha256_wide=%s\n' "$hash_wide"
printf 'resize_cpr_sha256_narrow=%s\n' "$hash_narrow"
