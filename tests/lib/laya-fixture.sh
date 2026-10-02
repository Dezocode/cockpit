#!/usr/bin/env bash
# Shared helpers for the Laya tests (sourced after tests/lib/fixture.sh).
# Every stub runs on an ephemeral 127.0.0.1 port picked here; teardown kills
# only the PIDs these helpers started (never by port, never by name).

LAYA_TEST_STUB_PIDS=()
LAYA_TEST_NAME=${LAYA_TEST_NAME:-laya}
# The real python (>= 3.11, tomllib), resolved before a test plants curl/python
# sentinels in fakebin. macOS /usr/bin/python3 is 3.9, so versioned names first.
LAYA_TEST_PY=""
# (Homebrew's unversioned python3 too, when brew's bin is not on PATH.)
for _laya_py in python3.13 python3.12 python3.11 /opt/homebrew/bin/python3 /usr/local/bin/python3 python3; do
  _laya_py="$(command -v "$_laya_py" 2>/dev/null)" || continue
  if "$_laya_py" -c 'import tomllib' 2>/dev/null; then
    LAYA_TEST_PY=$_laya_py
    break
  fi
done
unset _laya_py
if [[ -z "$LAYA_TEST_PY" ]]; then
  printf '%s: FAIL (no python >= 3.11 with tomllib on PATH)\n' "$LAYA_TEST_NAME"
  exit 1
fi

laya_fail() {
  printf '%s: FAIL (%s)\n' "$LAYA_TEST_NAME" "$1"
  exit 1
}

laya_pick_port() {
  "$LAYA_TEST_PY" -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

laya_now_ms() {
  "$LAYA_TEST_PY" -c 'import time; print(int(time.time() * 1000))'
}

laya_venv_root() {
  printf '%s/.local/share/cockpit/laya/venv\n' "$HOME"
}

# A stand-in venv: python wraps the system python3 with a fake laya dist-info
# (version 0.3.99 + real console-script names); laya-serve runs the stub.
laya_make_venv() {
  local venv site
  venv="$(laya_venv_root)"
  site="$venv/lib/cockpit-test-site"
  mkdir -p "$venv/bin" "$site/laya-0.3.99.dist-info"
  printf 'Metadata-Version: 2.1\nName: laya\nVersion: 0.3.99\n' >"$site/laya-0.3.99.dist-info/METADATA"
  printf '[console_scripts]\nlaya = laya.cli:main\nlaya-mcp-server = laya.mcp.server:main\nlaya-serve = laya.serve:main\n' \
    >"$site/laya-0.3.99.dist-info/entry_points.txt"
  cat >"$venv/bin/python" <<PY
#!/usr/bin/env bash
PYTHONPATH="$site" exec "$LAYA_TEST_PY" "\$@"
PY
  cat >"$venv/bin/laya-serve" <<SERVE
#!/usr/bin/env bash
exec "$LAYA_TEST_PY" "$FIXTURE_REPO_ROOT/tests/fixtures/fake-laya-serve.py"
SERVE
  cat >"$venv/bin/laya-mcp-server" <<MCP
#!/usr/bin/env bash
printf 'laya-mcp-server was executed\n' >>"$FIXTURE_TEST_ROOT/mcp-server-ran"
exit 1
MCP
  # stub_bin is the temp venv bin; the name is what the mode-repair lint allows.
  stub_bin="$venv/bin"
  chmod 0755 "$stub_bin/python" "$stub_bin/laya-serve" "$stub_bin/laya-mcp-server"
}

laya_write_key() {
  local key=${1:-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef}
  mkdir -p "$HOME/.local/state/cockpit/laya"
  chmod 700 "$HOME/.local/state/cockpit/laya"
  (umask 077 && printf '%s\n' "$key" >"$HOME/.local/state/cockpit/laya/api.key")
}

laya_key() {
  IFS= read -r key <"$HOME/.local/state/cockpit/laya/api.key"
  printf '%s\n' "$key"
}

# laya_write_conf ENABLED PORT [TIMEOUT_MS] [extra lines...]
laya_write_conf() {
  local enabled=$1 port=$2 timeout_ms=${3:-2000}
  shift 3 2>/dev/null || shift $#
  mkdir -p "$HOME/.config/cockpit"
  {
    printf 'enabled=%s\nurl=http://127.0.0.1:%s\ndevice=cpu\ntimeout_ms=%s\n' "$enabled" "$port" "$timeout_ms"
    printf 'min_confidence=0.60\ndefault_tier=cheap\nmax_tier=top\n'
    local line
    for line in "$@"; do printf '%s\n' "$line"; done
  } >"$HOME/.config/cockpit/laya.conf"
}

laya_write_providers() {
  mkdir -p "$HOME/.config/cockpit"
  cat >"$HOME/.config/cockpit/providers.conf" <<'EOF2'
[codex]
label=Codex
kind=runtime
check=true
start=codex

[stubrt]
label=Stub runtime
kind=runtime
check=true
start=stubrt
tiers=cheap:stub-cheap,standard:stub-standard,top:stub-top
model_apply=printf '%s:%s\n' "$COCKPIT_PROVIDER" "$COCKPIT_MODEL" >>"$LAYA_TEST_APPLIED"

[notiers]
label=No tiers
kind=runtime
check=true
start=notiers
EOF2
}

# laya_start_stub PORT KEY RECORD_DIR [ENV=VALUE...]: our own stub, ready on return.
# Waits up to 30 s (a cold Homebrew python on a macOS runner can take seconds),
# fails at once if the stub dies, and shows its stderr.
laya_start_stub() {
  local port=$1 key=$2 rec=$3 i pid
  shift 3
  mkdir -p "$rec"
  rm -f "$rec"/*
  env LAYA_HOST=127.0.0.1 LAYA_PORT="$port" LAYA_API_KEY="$key" FAKE_LAYA_QUIET=1 \
    FAKE_LAYA_RECORD_DIR="$rec" "$@" "$LAYA_TEST_PY" "$FIXTURE_REPO_ROOT/tests/fixtures/fake-laya-serve.py" \
    2>"$rec.stderr" &
  pid=$!
  LAYA_TEST_STUB_PIDS+=("$pid")
  for ((i = 0; i < 600; i++)); do
    [[ -s "$rec/listening.txt" ]] && return 0
    if ! kill -0 "$pid" 2>/dev/null; then
      laya_fail "stub exited before listening on 127.0.0.1:$port: $(tail -5 "$rec.stderr" 2>/dev/null)"
    fi
    sleep 0.05
  done
  laya_fail "stub did not start on 127.0.0.1:$port within 30 s: $(tail -5 "$rec.stderr" 2>/dev/null)"
}

laya_stop_stubs() {
  local pid
  for pid in "${LAYA_TEST_STUB_PIDS[@]:-}"; do
    [[ -n "$pid" ]] || continue
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  LAYA_TEST_STUB_PIDS=()
}

laya_install_cleanup() {
  laya_cleanup() {
    laya_stop_stubs
    # laya-serve started by `cockpit laya start` is ours too: stop it via its pidfile.
    if [[ -f "$HOME/.local/state/cockpit/laya/laya-serve.pid" ]]; then
      bash "$FIXTURE_REPO_ROOT/bin/cockpit-laya" stop >/dev/null 2>&1 || true
    fi
    fixture_cleanup
  }
  trap laya_cleanup EXIT
}

# JSON field from one line (python3 is fine in tests).
laya_json_get() {
  "$LAYA_TEST_PY" -c 'import json, sys
v = json.loads(sys.argv[1])
for k in sys.argv[2].split("."):
    v = v[k]
print(json.dumps(v) if not isinstance(v, str) else v)' "$1" "$2"
}
