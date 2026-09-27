#!/usr/bin/env bash
# Laya-first router: absent/off are invisible (no curl, no python, no stderr),
# a real answer is applied through providers.conf, every failure falls back fast.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init laya-router
LAYA_TEST_NAME=laya-router
# shellcheck source=lib/laya-fixture.sh
source "$repo_root/tests/lib/laya-fixture.sh"
laya_install_cleanup
unset COCKPIT_LAYA COCKPIT_LAYA_URL COCKPIT_LAYA_TIMEOUT_MS LAYA_HOST LAYA_PORT LAYA_API_KEY XDG_STATE_HOME XDG_CONFIG_HOME XDG_DATA_HOME
export LAYA_TEST_APPLIED="$FIXTURE_TEST_ROOT/applied.log"
route="$repo_root/bin/cockpit-route"
laya="$repo_root/bin/cockpit-laya"
receipts="$HOME/.local/state/cockpit/route.jsonl"
cd "$FIXTURE_TEST_ROOT"

# Sentinels: any curl/python spawned on the absent/off path is logged here.
sentinel_log="$FIXTURE_TEST_ROOT/sentinel.log"
for tool in curl python python3; do
  printf '#!/bin/sh\necho "%s $*" >>"%s"\nexit 99\n' "$tool" "$sentinel_log" >"$FIXTURE_FAKEBIN/$tool"
  chmod 0755 "$FIXTURE_FAKEBIN/$tool"
done

# --- absent: clean HOME, no venv -------------------------------------------
laya_write_providers
out="$(bash "$route" --json 'fix flaky test' 2>"$FIXTURE_TEST_ROOT/absent.err")" || laya_fail "absent: route exit $?"
[[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" == 1 ]] || laya_fail "absent: not one JSON line"
[[ "$out" == *'"laya":"absent"'* && "$out" == *'"tier":"cheap"'* && "$out" == *'"tool":"codex"'* ]] ||
  laya_fail "absent: $out"
# Through the real dispatcher (exec needs the committed 100755 modes).
status_out="$("$repo_root/bin/cockpit" laya status 2>>"$FIXTURE_TEST_ROOT/absent.err")" || laya_fail "absent: status exit $?"
[[ "$status_out" == 'laya: absent (routing off)' ]] || laya_fail "absent: status '$status_out'"
out2="$("$repo_root/bin/cockpit" route --json 'fix flaky test' 2>>"$FIXTURE_TEST_ROOT/absent.err")" || laya_fail "absent: cockpit route exit $?"
[[ "${out2/\"latency_ms\":0/}" == "${out/\"latency_ms\":0/}" ]] || laya_fail "absent: dispatcher route differs"
plugin_out="$("$repo_root/bin/cockpit" plugin run cockpit.laya status 2>>"$FIXTURE_TEST_ROOT/absent.err")" ||
  laya_fail "absent: plugin run exit $?"
[[ "$plugin_out" == 'laya: absent (routing off)' ]] || laya_fail "absent: plugin run '$plugin_out'"
"$repo_root/bin/cockpit" plugin list 2>/dev/null | grep -q '^cockpit.laya' || laya_fail "absent: plugin list"
"$repo_root/bin/cockpit" -h | grep -q '^  laya ' || laya_fail "absent: cockpit -h lacks laya"
[[ ! -s "$sentinel_log" ]] || laya_fail "absent: spawned $(tr '\n' ';' <"$sentinel_log")"
[[ ! -s "$FIXTURE_TEST_ROOT/absent.err" ]] || laya_fail "absent: wrote to stderr"
[[ "$(wc -l <"$receipts" | tr -d ' ')" == 2 ]] || laya_fail "absent: expected one receipt line per decision"

# --- off: venv present, enabled=0, then COCKPIT_LAYA=0 over enabled=1 --------
laya_make_venv
venv="$(laya_venv_root)"
mv "$venv/bin/python" "$venv/bin/python.real"
printf '#!/bin/sh\necho "venv-python $*" >>"%s"\nexit 99\n' "$sentinel_log" >"$venv/bin/python"
chmod 0755 "$venv/bin/python"
laya_write_key
port="$(laya_pick_port)"
laya_write_conf 0 "$port" 2000
out="$(bash "$route" --json 'task' 2>&1)"
[[ "$out" == *'"laya":"off"'* ]] || laya_fail "off enabled=0: $out"
laya_write_conf 1 "$port" 2000
out="$(COCKPIT_LAYA=0 bash "$route" --json 'task' 2>&1)"
[[ "$out" == *'"laya":"off"'* ]] || laya_fail "off COCKPIT_LAYA=0: $out"
[[ ! -s "$sentinel_log" ]] || laya_fail "off: spawned $(tr '\n' ';' <"$sentinel_log")"
mv "$venv/bin/python.real" "$venv/bin/python"
rm -f "$FIXTURE_FAKEBIN/curl" "$FIXTURE_FAKEBIN/python" "$FIXTURE_FAKEBIN/python3"

# --- stub-routed: tier + tool applied, COCKPIT_MODEL from tiers=, model_apply ran
rec="$FIXTURE_TEST_ROOT/rec"
key="$(laya_key)"
laya_start_stub "$port" "$key" "$rec"
out="$(bash "$route" --json 'rename a variable in one file' 2>&1)"
[[ "$out" == *'"laya":"ok"'* && "$out" == *'"tier":"cheap"'* && "$out" == *'"tool":"stubrt"'* ]] ||
  laya_fail "stub-routed: $out"
[[ "$(laya_json_get "$out" conf.tier)" == 0.82 && "$(laya_json_get "$out" applied.model)" == stub-cheap ]] ||
  laya_fail "stub-routed: conf/applied $out"
[[ "$(tail -1 "$LAYA_TEST_APPLIED" 2>/dev/null)" == stubrt:stub-cheap ]] || laya_fail "stub-routed: model_apply did not run"
body="$(cat "$rec/body.json")"
[[ "$(laya_json_get "$body" state.request)" == 'rename a variable in one file' ]] || laya_fail "stub-routed: request body"
[[ "$(laya_json_get "$body" questions.tier.type)" == choice && "$(laya_json_get "$body" questions.needs_review.type)" == noul ]] ||
  laya_fail "stub-routed: questions shape"
model="$(
  # shellcheck source=../bin/cockpit-lib
  source "$repo_root/bin/cockpit-lib"
  cockpit_route_run 'architecture change across repos'
  printf '%s|%s|%s' "${COCKPIT_PROVIDER:-}" "${COCKPIT_MODEL:-}" "$COCKPIT_ROUTE_TIER"
)"
[[ "$model" == 'stubrt|stub-top|top' ]] || laya_fail "stub-routed: exported $model"
out="$(COCKPIT_LAYA_MAX_TIER=standard bash "$route" --json 'architecture change across repos')"
[[ "$out" == *'"tier":"standard"'* && "$out" == *clamped_to_max_tier* ]] || laya_fail "stub-routed: max_tier clamp $out"
out="$(bash "$route" --json 'rename x needs-review sensitive')"
[[ "$out" == *'"needs_review":true'* && "$out" == *'"is_sensitive":true'* ]] || laya_fail "stub-routed: noul $out"
out="$(bash "$route" --json 'rename x')"
[[ "$out" == *'"needs_review":false'* && "$out" == *'"is_sensitive":false'* ]] || laya_fail "stub-routed: noul false $out"

# --- down: nothing listens on the port ---------------------------------------
down_port="$(laya_pick_port)"
out="$(COCKPIT_LAYA_URL="http://127.0.0.1:$down_port" bash "$route" --json 'task' 2>&1)"
[[ "$out" == *'"laya":"down"'* && "$out" == *'"tool":"codex"'* && "$out" == *curl_exit_7* ]] || laya_fail "down: $out"

# --- timeout: stub delays 5000 ms, timeout_ms=300. The call must give up at the
# timeout: its wall time stays within an ok call's time (same machine, same
# process startup cost) + 300 ms + slack, far below the stub's 5 s.
t0="$(laya_now_ms)"
out="$(bash "$route" --json 'rename x')"
t1="$(laya_now_ms)"
[[ "$out" == *'"laya":"ok"'* ]] || laya_fail "timeout: baseline ok call $out"
baseline=$((t1 - t0))
slow_port="$(laya_pick_port)"
laya_start_stub "$slow_port" "$key" "$FIXTURE_TEST_ROOT/rec-slow" LAYA_STUB_SLEEP_MS=5000
t0="$(laya_now_ms)"
rc=0
out="$(COCKPIT_LAYA_URL="http://127.0.0.1:$slow_port" COCKPIT_LAYA_TIMEOUT_MS=300 bash "$route" --json 'rename x')" || rc=$?
t1="$(laya_now_ms)"
[[ "$rc" == 0 && "$out" == *'"laya":"timeout"'* && "$out" == *'"tier":"cheap"'* && "$out" == *'"tool":"codex"'* ]] ||
  laya_fail "timeout: rc=$rc $out"
latency="$(laya_json_get "$out" latency_ms)"
((latency >= 250 && latency < 1000)) || laya_fail "timeout: curl waited ${latency} ms for timeout_ms=300"
((t1 - t0 < baseline + 300 + 1200)) || laya_fail "timeout: took $((t1 - t0)) ms (ok call ${baseline} ms)"

# --- low-confidence: conf 0.40 < 0.60 → defaults --------------------------------
out="$(bash "$route" --json 'low-confidence architecture task')"
[[ "$out" == *'"laya":"ok"'* && "$out" == *'"tier":"cheap"'* && "$out" == *'"tool":"codex"'* ]] ||
  laya_fail "low-confidence: $out"
[[ "$out" == *low_confidence_tier* && "$out" == *'"applied":{"provider":null,"model":null}'* ]] ||
  laya_fail "low-confidence: reason/applied $out"

# --- tiers-map: chosen provider has no tiers= → model untouched -----------------
laya_stop_stubs
laya_start_stub "$port" "$key" "$rec" LAYA_FORCE_TOOL=notiers
model="$(
  # shellcheck source=../bin/cockpit-lib
  source "$repo_root/bin/cockpit-lib"
  export COCKPIT_MODEL=user-picked
  cockpit_route_run 'rename x'
  printf '%s|%s|%s' "$COCKPIT_ROUTE_TOOL" "${COCKPIT_MODEL:-}" "$COCKPIT_ROUTE_APPLIED_MODEL"
)"
[[ "$model" == 'notiers|user-picked|' ]] || laya_fail "tiers-map: $model"
laya_stop_stubs
laya_start_stub "$port" "$key" "$rec"

# --- receipt-no-text: sha256 only ------------------------------------------------
secret_task='unique-receipt-phrase-xyzzy @/etc/passwd'
before="$(wc -l <"$receipts" | tr -d ' ')"
bash "$route" --json "$secret_task" >/dev/null
after="$(wc -l <"$receipts" | tr -d ' ')"
((after == before + 1)) || laya_fail "receipt-no-text: expected one new receipt line"
last="$(tail -1 "$receipts")"
want_sha="$(printf '%s' "$secret_task" | "$LAYA_TEST_PY" -c 'import hashlib, sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())')"
[[ "$(laya_json_get "$last" task_sha256)" == "$want_sha" && "$(laya_json_get "$last" laya)" == ok ]] ||
  laya_fail "receipt-no-text: sha/laya $last"
if grep -F -q 'unique-receipt-phrase-xyzzy' "$receipts"; then
  laya_fail "receipt-no-text: task text in route.jsonl"
fi
"$LAYA_TEST_PY" -c 'import json, sys
keys = {"ts","laya","latency_ms","task_sha256","tier","tool","conf","needs_review","is_sensitive","applied","reason"}
for n, line in enumerate(open(sys.argv[1]), 1):
    rec = json.loads(line)
    assert set(rec) == keys, (n, sorted(rec))' "$receipts" || laya_fail "receipt-no-text: receipt schema"

# --- loopback-bind: `cockpit laya start` forces LAYA_HOST=127.0.0.1 --------------
laya_stop_stubs
serve_rec="$FIXTURE_TEST_ROOT/rec-serve"
mkdir -p "$serve_rec"
serve_port="$(laya_pick_port)"
laya_write_conf 0 "$serve_port" 2000
start_out="$(LAYA_HOST=0.0.0.0 LAYA_API_KEY=not-the-key LAYA_STUB_RECORD_DIR="$serve_rec" LAYA_STUB_QUIET=1 \
  COCKPIT_LAYA_START_TIMEOUT_S=15 bash "$laya" start 2>&1)" || laya_fail "loopback-bind: start failed: $start_out"
[[ "$(cat "$serve_rec/host.txt")" == 127.0.0.1 ]] || laya_fail "loopback-bind: served LAYA_HOST=$(cat "$serve_rec/host.txt")"
[[ "$(cat "$serve_rec/listening.txt")" == "127.0.0.1:$serve_port" ]] || laya_fail "loopback-bind: listening $(cat "$serve_rec/listening.txt")"
[[ "$start_out" == "laya: serving 127.0.0.1:$serve_port device=cpu version=0.3.99" ]] || laya_fail "loopback-bind: start said '$start_out'"
if grep -q "$key" "$serve_rec/argv.txt"; then laya_fail "loopback-bind: key on laya-serve argv"; fi
status_out="$(bash "$laya" status)"
[[ "$status_out" == "laya: serving 127.0.0.1:$serve_port device=cpu version=0.3.99" ]] || laya_fail "loopback-bind: status '$status_out'"
status_json="$(bash "$laya" status --json)"
[[ "$(laya_json_get "$status_json" state)" == serving && "$(laya_json_get "$status_json" loopback)" == true ]] ||
  laya_fail "loopback-bind: status json $status_json"
out="$(bash "$route" --json 'rename a variable in one file')"
[[ "$out" == *'"laya":"ok"'* ]] || laya_fail "loopback-bind: route via started server $out"
key_mode="$(ls -l "$HOME/.local/state/cockpit/laya/api.key")"
[[ "${key_mode:0:10}" == -rw------- ]] || laya_fail "loopback-bind: api.key not 0600"
bash "$laya" stop >/dev/null
[[ ! -f "$HOME/.local/state/cockpit/laya/laya-serve.pid" ]] || laya_fail "loopback-bind: pidfile left behind"
out="$(bash "$route" --json 'rename x')"
[[ "$out" == *'"laya":"down"'* ]] || laya_fail "loopback-bind: after stop $out"

printf 'laya-router: ok (absent, off, stub-routed, down, timeout, low-confidence, tiers-map, receipt-no-text, loopback-bind)\n'
