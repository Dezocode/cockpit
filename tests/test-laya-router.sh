#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init laya-router

export COCKPIT_AUTH_HOME="$HOME/.config/cockpit"
mkdir -p "$COCKPIT_AUTH_HOME"
stub_pid=""

laya_venv() {
  local root="$HOME/.local/share/cockpit/laya/venv"
  mkdir -p "$root/bin"
  if [[ ! -x "$root/bin/python" ]]; then
    ln -sf "$(command -v python3)" "$root/bin/python"
  fi
  if [[ ! -x "$root/bin/laya-serve" ]]; then
    printf '#!/bin/sh\nexit 0\n' >"$root/bin/laya-serve"
    chmod 0755 "$root/bin/laya-serve"
  fi
}

pick_port() {
  python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'
}

stop_stub() {
  [[ -n "$stub_pid" ]] && kill "$stub_pid" 2>/dev/null || true
  wait "$stub_pid" 2>/dev/null || true
  stub_pid=""
}

start_stub() {
  local port=$1 key=$2 host_file=${3:-}
  stop_stub
  export LAYA_HOST=127.0.0.1
  export LAYA_PORT=$port
  export LAYA_API_KEY=$key
  export LAYA_STUB_QUIET=1
  export LAYA_RECORD_HOST_FILE=$host_file
  python3 "$repo_root/tests/fixtures/fake-laya-serve.py" &
  stub_pid=$!
  sleep 0.3
}

write_providers() {
  cat >"$COCKPIT_AUTH_HOME/providers.conf" <<'EOF'
[codex]
label=Codex
kind=runtime
check=command -v true
start=codex

[stubrt]
label=Stub runtime
kind=runtime
check=command -v true
start=stubrt
tiers=cheap:stub-model,standard:stub-standard,top:stub-top

[notiers]
label=No tiers
kind=runtime
check=command -v true
start=notiers
EOF
}

seed_laya_conf() {
  local enabled=$1 port=$2 timeout_ms=${3:-400}
  install -m 0644 "$repo_root/stage/laya/laya.conf" "$HOME/.config/cockpit/laya.conf"
  {
    grep -v '^enabled=' "$HOME/.config/cockpit/laya.conf" | grep -v '^url=' | grep -v '^timeout_ms=' || true
    printf 'enabled=%s\n' "$enabled"
    printf 'url=http://127.0.0.1:%s\n' "$port"
    printf 'timeout_ms=%s\n' "$timeout_ms"
  } >"$HOME/.config/cockpit/laya.conf.tmp"
  mv "$HOME/.config/cockpit/laya.conf.tmp" "$HOME/.config/cockpit/laya.conf"
}

write_key() {
  mkdir -p "$HOME/.local/state/cockpit/laya"
  printf 'test-key-32bytes-hex-placeholder00\n' >"$HOME/.local/state/cockpit/laya/api.key"
  chmod 600 "$HOME/.local/state/cockpit/laya/api.key"
}

trap stop_stub EXIT

# absent
cat >"$FIXTURE_FAKEBIN/curl" <<'EOF'
#!/bin/sh
echo sentinel-curl >&2
exit 99
EOF
cat >"$FIXTURE_FAKEBIN/python3" <<'EOF'
#!/bin/sh
echo sentinel-python >&2
exit 99
EOF
chmod 0755 "$FIXTURE_FAKEBIN/curl" "$FIXTURE_FAKEBIN/python3"
write_providers
rm -rf "$HOME/.local/share/cockpit/laya" "$HOME/.config/cockpit/laya.conf" 2>/dev/null || true
out="$(bash "$repo_root/bin/cockpit-route" --json 'fix flaky test' 2>&1)"
[[ "$out" == *'"laya":"absent"'* ]]
[[ "$out" == *'"tier":"cheap"'* ]]
status_out="$(bash "$repo_root/bin/cockpit-laya" status; echo rc=$?)"
[[ "$status_out" == *'laya: absent (routing off)'* ]]
[[ "$status_out" == *'rc=0'* ]]
rm -f "$FIXTURE_FAKEBIN/curl" "$FIXTURE_FAKEBIN/python3"

# off
laya_venv
port="$(pick_port)"
write_key
seed_laya_conf 0 "$port"
export COCKPIT_LAYA=0
out="$(bash "$repo_root/bin/cockpit-route" --json 'task' 2>&1)"
[[ "$out" == *'"laya":"off"'* ]]
unset COCKPIT_LAYA
seed_laya_conf 0 "$port"
out="$(bash "$repo_root/bin/cockpit-route" --json 'task' 2>&1)"
[[ "$out" == *'"laya":"off"'* ]]

# stub-routed + loopback host record
host_file="$FIXTURE_TEST_ROOT/laya-host.txt"
seed_laya_conf 1 "$port"
start_stub "$port" test-key-32bytes-hex-placeholder00 "$host_file"
write_providers
task='rename a variable in one file'
out="$(bash "$repo_root/bin/cockpit-route" --json "$task" 2>&1)"
[[ "$out" == *'"laya":"ok"'* ]]
[[ "$out" == *'"tool":"stubrt"'* ]]
[[ "$out" == *'"tier":"cheap"'* ]]
applied_model="$(
  # shellcheck source=../bin/cockpit-lib
  source "$repo_root/bin/cockpit-lib"
  export COCKPIT_AUTH_HOME
  cockpit_route_run "$task"
  printf '%s' "${COCKPIT_MODEL:-}"
)"
[[ "$applied_model" == stub-model ]]
[[ -f "$host_file" ]] && [[ "$(tr -d '\n' <"$host_file")" == 127.0.0.1 ]]

# down
stop_stub
out="$(bash "$repo_root/bin/cockpit-route" --json 'task' 2>&1)"
[[ "$out" == *'"laya":"down"'* ]]

# timeout
export LAYA_STUB_SLEEP_MS=2000
start_stub "$port" test-key-32bytes-hex-placeholder00
seed_laya_conf 1 "$port" 300
t0=$(python3 -c 'import time; print(int(time.time()*1000))')
out="$(bash "$repo_root/bin/cockpit-route" --json 'task' 2>&1)"
t1=$(python3 -c 'import time; print(int(time.time()*1000))')
[[ "$out" == *'"laya":"timeout"'* ]]
(( t1 - t0 < 1000 ))
unset LAYA_STUB_SLEEP_MS

# low-confidence
start_stub "$port" test-key-32bytes-hex-placeholder00
seed_laya_conf 1 "$port" 400
out="$(bash "$repo_root/bin/cockpit-route" --json 'low-confidence task' 2>&1)"
[[ "$out" == *'"tier":"cheap"'* ]]

# tiers-map
export LAYA_FORCE_TOOL=notiers
start_stub "$port" test-key-32bytes-hex-placeholder00
write_providers
unset COCKPIT_MODEL
bash "$repo_root/bin/cockpit-route" --dry-run 'rename x' >/dev/null
[[ -z "${COCKPIT_MODEL:-}" ]]
unset LAYA_FORCE_TOOL

# receipt-no-text
secret_task='unique-receipt-secret-phrase-xyzzy'
rm -f "$HOME/.local/state/cockpit/route.jsonl"
write_providers
start_stub "$port" test-key-32bytes-hex-placeholder00
bash "$repo_root/bin/cockpit-route" --json "$secret_task" >/dev/null
! grep -F "$secret_task" "$HOME/.local/state/cockpit/route.jsonl"

printf 'laya-router: ok (absent, off, stub-routed, down, timeout, low-confidence, tiers-map, receipt-no-text, loopback-bind)\n'
