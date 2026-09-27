#!/usr/bin/env bash
# scripts/health-smoke.sh against a python stub server (run through
# COCKPIT_TEST_NODE): contract checks fail with their own label, and on a hang
# or failure the script stops only the server it started, leaving nothing behind.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
smoke="$repo_root/scripts/health-smoke.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/stub.py" <<'PY'
import http.server, json, os, sys, time
open(os.environ["STUB_PIDFILE"], "w").write(str(os.getpid()))
with open(os.environ["STUB_PIDFILE"] + ".host", "w") as fh:
    fh.write(os.environ.get("COCKPIT_WEB_HOST", "") + ":" + os.environ.get("COCKPIT_WEB_PORT", ""))
mode = os.environ["STUB_MODE"]
if mode == "exit":
    sys.exit(3)
if mode == "hang":
    while True:
        time.sleep(1)
body = {"product": "cockpit", "status": "yellow", "checks": {"hostinger": "configured"},
        "source": "app/dist-server/index.js"}
if mode == "badproduct":
    body["product"] = "codex"
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        data = json.dumps(body).encode()
        self.send_response(200 if self.path == "/api/health" else 404)
        self.send_header("content-type", "application/json")
        self.end_headers()
        self.wfile.write(data)
    def log_message(self, *a):
        pass
http.server.HTTPServer((os.environ["COCKPIT_WEB_HOST"], int(os.environ["COCKPIT_WEB_PORT"])), H).serve_forever()
PY

pass=0 fail=0
ok() { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n%s\n' "$1" "${2:-}"; fail=$((fail + 1)); }

n=0
run_stub() {
  local mode=$1 want=$2 pattern=$3 out rc=0
  n=$((n + 1))
  pidfile="$tmpdir/pid.$n"
  out="$(STUB_MODE="$mode" STUB_PIDFILE="$pidfile" COCKPIT_TEST_NODE=python3 HEALTH_SMOKE_TRIES=6 \
    "$smoke" "$tmpdir/stub.py" 2>&1 </dev/null)" || rc=$?
  if [[ "$rc" -eq "$want" ]] && grep -Eq -- "$pattern" <<<"$out"; then
    ok "$mode: rc=$rc"
  else
    bad "$mode: rc=$rc want $want, pattern $pattern" "$out"
  fi
  # The stub's own PID must be gone once health-smoke returns.
  if [[ -s "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    bad "$mode: stub pid $(cat "$pidfile") still alive after health-smoke returned"
    kill "$(cat "$pidfile")" 2>/dev/null || :
  else
    ok "$mode: no leftover server process"
  fi
}

run_stub good 0 '^health-smoke: ok status=yellow product=cockpit hostinger=configured \(127\.0\.0\.1:[0-9]+, own pid [0-9]+\)$'
if [[ "$(cat "$tmpdir/pid.1.host")" =~ ^127\.0\.0\.1:[0-9]+$ && "$(cat "$tmpdir/pid.1.host")" != *:8787 ]]; then
  ok "good: server bound to loopback on an ephemeral port ($(cat "$tmpdir/pid.1.host"))"
else
  bad "good: server bound to loopback on an ephemeral port" "$(cat "$tmpdir/pid.1.host")"
fi
run_stub badproduct 1 "health-smoke: FAIL product 'codex' != 'cockpit'"
run_stub exit 1 'health-smoke: FAIL server exited before answering'
run_stub hang 1 'health-smoke: FAIL no /api/health answer on 127\.0\.0\.1:[0-9]+ after 6 tries'

out="$("$smoke" "$tmpdir/missing.js" 2>&1)" && rc=0 || rc=$?
[[ "$rc" -eq 1 && "$out" == *"no server at"* ]] && ok "missing server file -> 1" || bad "missing server file -> 1 (rc=$rc)" "$out"

printf 'health-smoke tests: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
