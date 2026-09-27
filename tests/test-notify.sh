#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"

# fixture_init resets PATH to /usr/bin:/bin; CI node/pnpm live under setup-node-pnpm.
_notify_tool_dirs=""
for _tool in node pnpm; do
  if command -v "$_tool" >/dev/null 2>&1; then
    _notify_tool_dirs="$(dirname "$(command -v "$_tool")"):${_notify_tool_dirs}"
  fi
done

fixture_init notify

export PATH="$repo_root/bin:$FIXTURE_FAKEBIN:${_notify_tool_dirs}${PATH}"
mkdir -p "$FIXTURE_HOME/.config/cockpit" "$FIXTURE_HOME/.local/state/cockpit"
install -m 0644 "$repo_root/stage/notify/notify.conf" "$FIXTURE_HOME/.config/cockpit/notify.conf"

fail() { echo "notify: FAIL ($1)"; exit 1; }

# --- cli-contract ---
export COCKPIT_NOTIFY_DRY_RUN=1
line="$(cockpit notify "Cockpit v2.3.0 GTM done")"
printf '%s' "$line" | grep -q '^notify: delivered=dry-run sinks=dry-run:ok id=' || fail cli-contract
hash="$(printf '%s' 'Cockpit v2.3.0 GTM done' | openssl dgst -sha256 | awk '{print $NF}')"
last="$(tail -1 "$FIXTURE_HOME/.local/state/cockpit/notify.jsonl")"
[[ "$last" == *"\"message_sha256\":\"$hash\""* ]] || fail cli-contract-sha
line2="$(cockpit notify --dry-run multi word join)"
[[ "$line2" == notify:* ]] || fail cli-contract-words
printf 'stdin body\n' | cockpit notify --dry-run - | grep -q 'notify: delivered=dry-run' || fail cli-contract-stdin
unset COCKPIT_NOTIFY_DRY_RUN

# --- exit-codes ---
rc=0
cockpit notify >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 2 ]] || fail exit-usage
cockpit notify --dry-run "ok" >/dev/null || fail exit-0
rc=0
cockpit notify --require telegram "x" >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 3 ]] || fail exit-3

# --- hermes ---
cat >"$FIXTURE_FAKEBIN/hermes" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"${HERMES_LOG:?}"
exit 0
EOF
chmod +x "$FIXTURE_FAKEBIN/hermes"
export HERMES_LOG="$FIXTURE_TEST_ROOT/hermes.log"
: >"$HERMES_LOG"
export COCKPIT_TELEGRAM_BOT_TOKEN= COCKPIT_TELEGRAM_CHAT_ID=
cockpit notify --sink telegram "hermes path" >/dev/null || fail hermes
grep -qx 'send --to telegram -q hermes path' "$HERMES_LOG" || fail hermes-argv

# --- botapi-no-argv-token ---
TOKEN_PART_A=123456789
TOKEN_PART_B=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef
TOKEN_PART_C=ghi
TOKEN="${TOKEN_PART_A}:${TOKEN_PART_B}${TOKEN_PART_C}"
CHAT="999"
export COCKPIT_TELEGRAM_BOT_TOKEN="$TOKEN"
export COCKPIT_TELEGRAM_CHAT_ID="$CHAT"
unset HERMES_LOG
rm -f "$FIXTURE_FAKEBIN/hermes"
TG_LOG="$FIXTURE_TEST_ROOT/tg.log"
port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
python3 "$repo_root/tests/fixtures/fake-telegram-api.py" "$port" "$TG_LOG" &
tg_pid=$!
sleep 0.2
export COCKPIT_TELEGRAM_API_BASE="http://127.0.0.1:${port}"
cockpit notify --sink telegram "botapi sample" >/dev/null &
npid=$!
sleep 0.8
if ps -axww -o command= 2>/dev/null | grep -v grep | grep -q "$TOKEN"; then
  kill "$npid" 2>/dev/null || true
  fail botapi-argv-token
fi
wait "$npid" 2>/dev/null || true
grep -q sendMessage "$TG_LOG" || fail botapi-hit
kill "$tg_pid" 2>/dev/null || true

# --- ntfy stub ---
cat >"$FIXTURE_FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
real_curl=/usr/bin/curl
[[ -x /usr/bin/curl ]] || real_curl=curl
if [[ "${COCKPIT_NTFY_STUB:-}" == 1 ]]; then
  cfg=""
  prev=""
  for a in "$@"; do
    if [[ "$prev" == --config ]]; then
      cfg="$a"
      break
    fi
    prev="$a"
  done
  if [[ -n "$cfg" && -f "$cfg" ]]; then
    cat "$cfg" >>"${NTFY_LOG:?}"
    exit 0
  fi
fi
exec "$real_curl" "$@"
EOF
chmod +x "$FIXTURE_FAKEBIN/curl"
export NTFY_LOG="$FIXTURE_TEST_ROOT/ntfy.log"
export COCKPIT_NTFY_STUB=1
export COCKPIT_NTFY_TOPIC="secret-topic"
: >"$NTFY_LOG"
cockpit notify --sink ntfy "ntfy body" >/dev/null || fail ntfy
grep -q 'Title:' "$NTFY_LOG" || fail ntfy-title
grep -q 'Priority:' "$NTFY_LOG" || fail ntfy-priority
grep -q 'ntfy body' "$NTFY_LOG" || fail ntfy-body
unset COCKPIT_NTFY_STUB

# --- desktop ---
if [[ "$(uname -s)" == Darwin ]]; then
  cockpit notify --sink desktop "mac toast" >/dev/null && echo "desktop:ok via osascript"
else
  export DISPLAY=:99 DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null
  cat >"$FIXTURE_FAKEBIN/notify-send" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"${NOTIFY_SEND_LOG:?}"
exit 0
EOF
  chmod +x "$FIXTURE_FAKEBIN/notify-send"
  export NOTIFY_SEND_LOG="$FIXTURE_TEST_ROOT/notify-send.log"
  : >"$NOTIFY_SEND_LOG"
  cockpit notify --sink desktop "linux toast" >/dev/null || fail desktop
  grep -q Cockpit "$NOTIFY_SEND_LOG" || fail desktop-args
fi

# --- dedupe-id ---
export COCKPIT_NTFY_STUB=1
export COCKPIT_NTFY_TOPIC=t1
: >"$NTFY_LOG"
cockpit notify --sink ntfy --id dedupe-test -- once >/dev/null
hits=$(wc -l <"$NTFY_LOG")
out2="$(cockpit notify --sink ntfy --id dedupe-test -- once)"
[[ "$out2" == *deduped=true* ]] || fail dedupe
hits2=$(wc -l <"$NTFY_LOG")
[[ "$hits2" -eq "$hits" ]] || fail dedupe-count
unset COCKPIT_NTFY_STUB

# --- redaction ---
export COCKPIT_TELEGRAM_API_BASE="http://127.0.0.1:${port}"
python3 "$repo_root/tests/fixtures/fake-telegram-api.py" "$port" "$TG_LOG" &
tg_pid=$!
sleep 0.2
out_redact="$(cockpit notify --sink telegram "fail_token_leak" 2>&1 || true)"
kill "$tg_pid" 2>/dev/null || true
[[ "$out_redact" != *"$TOKEN"* ]] || fail redaction

# --- api-* (requires built dist-server) ---
api_skip=0
if [[ ! -f "$repo_root/app/dist-server/index.js" ]]; then
  if command -v pnpm >/dev/null 2>&1 && [[ -f "$repo_root/app/package.json" ]]; then
    (cd "$repo_root/app" && pnpm install --frozen-lockfile >/dev/null && pnpm run build:server >/dev/null) || api_skip=1
  else
    api_skip=1
  fi
fi
[[ -f "$repo_root/app/dist-server/index.js" ]] || api_skip=1

if [[ "$api_skip" -eq 0 ]]; then
  export COCKPIT_NOTIFY_KEY="test-notify-key"
  export COCKPIT_NOTIFY_DRY_RUN=1
  export COCKPIT_HOSTINGER=1
  export COCKPIT_WEB_PORT=18787
  COCKPIT_HOSTINGER=1 COCKPIT_NOTIFY_KEY="$COCKPIT_NOTIFY_KEY" COCKPIT_NOTIFY_DRY_RUN=1 \
    node "$repo_root/app/dist-server/index.js" >"$FIXTURE_TEST_ROOT/server.log" 2>&1 &
  srv_pid=$!
  for _ in $(seq 1 40); do
    curl -s -o /dev/null "http://127.0.0.1:${COCKPIT_WEB_PORT}/api/health" && break
    sleep 0.15
  done
  code="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"message":"x"}' "http://127.0.0.1:${COCKPIT_WEB_PORT}/api/notify")"
  [[ "$code" == "401" ]] || fail api-auth-401
  body="$(curl -s -X POST -H 'content-type: application/json' -H "Authorization: Bearer $COCKPIT_NOTIFY_KEY" -d '{"message":"x"}' "http://127.0.0.1:${COCKPIT_WEB_PORT}/api/notify")"
  [[ "$body" == *'"delivered":"dry-run"'* ]] || fail api-auth-200
  [[ "$body" != *"$COCKPIT_NOTIFY_KEY"* ]] || fail api-secret
  code_lt="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -H 'X-Local: 1' -d '{"message":"x"}' "http://127.0.0.1:${COCKPIT_WEB_PORT}/api/notify")"
  [[ "$code_lt" == "401" ]] || fail api-local-trust
  for i in $(seq 1 11); do
    c="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -H "Authorization: Bearer $COCKPIT_NOTIFY_KEY" -d "{\"message\":\"r$i\"}" "http://127.0.0.1:${COCKPIT_WEB_PORT}/api/notify")"
    last_code=$c
  done
  [[ "$last_code" == "429" ]] || fail api-ratelimit
  if grep -E "$COCKPIT_NOTIFY_KEY|Bearer" "$FIXTURE_TEST_ROOT/server.log"; then
    fail api-no-secret-echo
  fi
  kill "$srv_pid" 2>/dev/null || true
else
  fail api-missing-dist
fi

echo "notify: ok (cli-contract, exit-codes, hermes, botapi-no-argv-token, ntfy, desktop, dedupe-id, redaction, api-auth, api-ratelimit, api-no-secret-echo)"
