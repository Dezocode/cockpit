#!/usr/bin/env bash
# GET /api/health against a dist-server this script starts itself, on an
# ephemeral 127.0.0.1 port it picked; teardown stops only that recorded PID
# (EXIT trap, also on failure). Never binds or frees the product port 8787.
#   health-smoke.sh [path/to/dist-server/index.js]   (default: app/dist-server/index.js)
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
server="${1:-$root/app/dist-server/index.js}"
node_bin="${COCKPIT_TEST_NODE:-node}"
[[ -f "$server" ]] || { echo "health-smoke: FAIL no server at $server" >&2; exit 1; }
command -v "$node_bin" >/dev/null 2>&1 || { echo "health-smoke: FAIL node not found" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "health-smoke: FAIL python3 not found" >&2; exit 2; }

port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
work="$(mktemp -d)"
pid=""
cleanup() {
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null || :
    wait "$pid" 2>/dev/null || :
  fi
  rm -rf "$work"
}
trap cleanup EXIT

env COCKPIT_HOSTINGER=1 COCKPIT_WEB_PORT="$port" COCKPIT_WEB_HOST=127.0.0.1 \
  "$node_bin" "$server" >"$work/server.log" 2>&1 &
pid=$!

tries="${HEALTH_SMOKE_TRIES:-60}"
for _ in $(seq 1 "$tries"); do
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "health-smoke: FAIL server exited before answering (port $port)" >&2
    cat "$work/server.log" >&2
    pid=""
    exit 1
  fi
  if curl -sf --max-time 2 "http://127.0.0.1:${port}/api/health" -o "$work/health.json"; then
    break
  fi
  sleep 0.5
done
[[ -s "$work/health.json" ]] || {
  echo "health-smoke: FAIL no /api/health answer on 127.0.0.1:$port after $tries tries" >&2
  cat "$work/server.log" >&2
  exit 1
}

python3 - "$work/health.json" "$port" "$pid" <<'PY'
import json
import sys

path, port, pid = sys.argv[1:4]
d = json.load(open(path))
problems = []
if d.get("product") != "cockpit":
    problems.append(f"product {d.get('product')!r} != 'cockpit'")
if d.get("status") not in ("green", "yellow"):
    problems.append(f"status {d.get('status')!r} not green|yellow")
if (d.get("checks") or {}).get("hostinger") != "configured":
    problems.append("checks.hostinger != 'configured'")
if d.get("source") != "app/dist-server/index.js":
    problems.append(f"source {d.get('source')!r} != 'app/dist-server/index.js'")
if problems:
    print("health-smoke: FAIL " + "; ".join(problems), file=sys.stderr)
    print(json.dumps(d, indent=2), file=sys.stderr)
    sys.exit(1)
print(f"health-smoke: ok status={d['status']} product=cockpit hostinger=configured (127.0.0.1:{port}, own pid {pid})")
PY
