#!/usr/bin/env bash
# C7: cockpit notify + /api/notify. One case per done-line-2 label. Zero live sends:
# Telegram and ntfy are a local stub (tests/fixtures/fake-telegram-api.py) on an
# ephemeral 127.0.0.1 port; the API server gets its own ephemeral loopback port.
# Only processes this script started are ever stopped (by PID, never by port).
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Resolve node before fixture_init resets PATH: CI passes COCKPIT_TEST_NODE into its
# env -i sandbox (setup-node lives outside /usr/bin). The API cases need it; no skip.
node_bin="${COCKPIT_TEST_NODE:-$(command -v node || true)}"
export COCKPIT_TEST_NODE="$node_bin"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init notify

state_file="$FIXTURE_HOME/.local/state/cockpit/notify.jsonl"
mkdir -p "$FIXTURE_HOME/.config/cockpit"
install -m 0644 "$repo_root/stage/notify/notify.conf" "$FIXTURE_HOME/.config/cockpit/notify.conf"
unset COCKPIT_TELEGRAM_BOT_TOKEN COCKPIT_TELEGRAM_CHAT_ID COCKPIT_NOTIFY_KEY COCKPIT_NOTIFY_URL \
  COCKPIT_NTFY_TOPIC COCKPIT_NTFY_TOKEN COCKPIT_NTFY_SERVER COCKPIT_TELEGRAM_API_BASE \
  COCKPIT_NOTIFY_DRY_RUN COCKPIT_LOCAL_TRUST COCKPIT_HOSTINGER DISPLAY WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
export COCKPIT_NOTIFY_ENV_FILE="$FIXTURE_TEST_ROOT/no-notify.env"  # never read the host's /etc file

our_pids=()
stop_ours() {
  local p
  for p in "${our_pids[@]}"; do kill "$p" 2>/dev/null || true; done
  for p in "${our_pids[@]}"; do wait "$p" 2>/dev/null || true; done
  our_pids=()
}
trap 'stop_ours; fixture_cleanup' EXIT

fail() { echo "notify: FAIL ($1)"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" >&2; exit 1; }
# shellcheck source=../bin/cockpit-portable-lib
source "$repo_root/bin/cockpit-portable-lib"
sha() { printf '%s' "$1" | cockpit_sha256 /dev/stdin; }

# start_stub LOG [--slow S] → sets stub_port, stub_pid
start_stub() {
  local log=$1; shift
  local pf="$FIXTURE_TEST_ROOT/stub.port.$RANDOM"
  python3 "$repo_root/tests/fixtures/fake-telegram-api.py" "$pf" "$log" "$@" &
  stub_pid=$!
  our_pids+=("$stub_pid")
  for _ in $(seq 1 100); do [[ -s "$pf" ]] && break; sleep 0.05; done
  [[ -s "$pf" ]] || fail stub-start
  stub_port="$(cat "$pf")"
}
stop_pid() { kill "$1" 2>/dev/null || true; wait "$1" 2>/dev/null || true; }
hits() { [[ -f "$1" ]] && grep -c "$2" "$1" || echo 0; }

# ---------------------------------------------------------------- cli-contract
out="$(COCKPIT_NOTIFY_DRY_RUN=1 cockpit notify "Cockpit v2.3.0 GTM done")" || fail cli-contract "rc=$?"
[[ "$out" =~ ^notify:\ delivered=dry-run\ sinks=dry-run:ok\ id=[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\ message_sha256=[0-9a-f]{64}\ message=Cockpit\ v2\.3\.0\ GTM\ done$ ]] ||
  fail cli-contract "$out"
[[ "$(tail -1 "$state_file")" == *"\"message_sha256\":\"$(sha 'Cockpit v2.3.0 GTM done')\""* ]] || fail cli-contract-sha
cockpit notify --dry-run --json multi   word "join" >/dev/null
[[ "$(tail -1 "$state_file")" == *"\"message_sha256\":\"$(sha 'multi word join')\""* ]] || fail cli-contract-words
printf 'line one\nline two\n' | cockpit notify --dry-run - >/dev/null
[[ "$(tail -1 "$state_file")" == *"\"message_sha256\":\"$(sha $'line one\nline two')\""* ]] || fail cli-contract-stdin
j="$(cockpit notify --dry-run --json --title 'T "q"' -- 'a "quoted" \ msg')"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["delivered"]=="dry-run" and d["title"]=="T \"q\"", d' "$j" ||
  fail cli-contract-json "$j"
cockpit -h 2>&1 | grep -q 'notify' || fail cli-contract-help

# ---------------------------------------------------------------- exit-codes (0/2/3 here; 4/5 in api-*)
rc=0; cockpit notify >/dev/null 2>&1 || rc=$?; [[ "$rc" -eq 2 ]] || fail "exit-2 empty rc=$rc"
rc=0; cockpit notify "   " >/dev/null 2>&1 || rc=$?; [[ "$rc" -eq 2 ]] || fail "exit-2 blank rc=$rc"
rc=0; cockpit notify --sink carrier-pigeon x >/dev/null 2>&1 || rc=$?; [[ "$rc" -eq 2 ]] || fail "exit-2 sink rc=$rc"
rc=0; cockpit notify --link http://insecure x >/dev/null 2>&1 || rc=$?; [[ "$rc" -eq 2 ]] || fail "exit-2 link rc=$rc"
rc=0; cockpit notify --bogus x >/dev/null 2>&1 || rc=$?; [[ "$rc" -eq 2 ]] || fail "exit-2 option rc=$rc"
cockpit notify --dry-run ok >/dev/null || fail exit-0
# nothing configured → nothing delivered → 3, with the receipt still printed
rc=0; out="$(cockpit notify --sink telegram "nobody home" 2>/dev/null)" || rc=$?
[[ "$rc" -eq 3 && "$out" == *"delivered=none sinks=telegram:skip:not-configured"* ]] || fail "exit-3 rc=$rc out=$out"
if [[ "$(uname -s)" != Darwin ]]; then
  rc=0; out="$(cockpit notify "headless, nothing configured" 2>/dev/null)" || rc=$?
  [[ "$rc" -eq 3 && "$out" == *"delivered=none"* ]] || fail "exit-3-headless rc=$rc out=$out"
  cockpit notify --check --json | grep -q '"telegram":"not-configured","ntfy":"not-configured","desktop":"headless"' ||
    fail check-json
fi

# ---------------------------------------------------------------- hermes
cat >"$FIXTURE_FAKEBIN/hermes" <<'SH'
#!/usr/bin/env bash
for a in "$@"; do printf '%s\0' "$a"; done >>"${HERMES_LOG:?}"
printf '\n' >>"$HERMES_LOG"
exit "${HERMES_RC:-0}"
SH
chmod +x "$FIXTURE_FAKEBIN/hermes"
export HERMES_LOG="$FIXTURE_TEST_ROOT/hermes.log"
: >"$HERMES_LOG"
out="$(cockpit notify "Cockpit v2.3.0 GTM done")" || fail hermes "$out"
# The best-effort toast is real where osascript exists (macOS runner, see the
# desktop section); a headless Linux sandbox skips it.
desk_expect=skip:headless
command -v osascript >/dev/null 2>&1 && desk_expect=ok
[[ "$out" == "notify: delivered=telegram sinks=telegram:ok,ntfy:skip:not-configured,desktop:${desk_expect} id="* ]] || fail hermes-line "$out"
[[ "$(head -1 "$HERMES_LOG" | tr '\0' '|')" == "send|--to|telegram|-q|Cockpit v2.3.0 GTM done|" ]] ||
  fail hermes-argv "$(tr '\0' '|' <"$HERMES_LOG")"
cockpit notify --check --json | grep -q '"telegram":"ready"' || fail hermes-check
# hermes failing and no Bot API configured → fail:hermes-rc-7, exit 3
rc=0; out="$(HERMES_RC=7 cockpit notify --sink telegram x 2>/dev/null)" || rc=$?
[[ "$rc" -eq 3 && "$out" == *"telegram:fail:hermes-rc-7"* ]] || fail "hermes-fail rc=$rc $out"
rm -f "$FIXTURE_FAKEBIN/hermes"

# ---------------------------------------------------------------- botapi-no-argv-token
TOKEN="$(printf '%s:%s' 7412589630 "AAH$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')")"
export COCKPIT_TELEGRAM_BOT_TOKEN="$TOKEN" COCKPIT_TELEGRAM_CHAT_ID=424242
TG_LOG="$FIXTURE_TEST_ROOT/tg.jsonl"
start_stub "$TG_LOG" --slow 2
export COCKPIT_TELEGRAM_API_BASE="http://127.0.0.1:${stub_port}"
cockpit notify --sink telegram "botapi sample & text=x" >"$FIXTURE_TEST_ROOT/botapi.out" 2>&1 &
npid=$!
our_pids+=("$npid")
seen_curl=0 leaked=0
for _ in $(seq 1 30); do
  snap="$(ps -axww -o command= 2>/dev/null || true)"
  [[ "$snap" == *"--config /dev/fd/"* ]] && seen_curl=1
  [[ "$snap" == *"$TOKEN"* || "$snap" == *"424242"* ]] && leaked=1
  kill -0 "$npid" 2>/dev/null || break
  sleep 0.1
done
wait "$npid" || fail botapi "$(cat "$FIXTURE_TEST_ROOT/botapi.out")"
[[ "$leaked" -eq 0 ]] || fail botapi-argv-token
[[ "$seen_curl" -eq 1 ]] || fail "botapi-sampler-never-saw-curl (sampler would be vacuous)"
python3 - "$TG_LOG" "$TOKEN" <<'PY' || fail botapi-body
import json, sys, urllib.parse
reqs = [json.loads(l) for l in open(sys.argv[1])]
r = [x for x in reqs if x["path"].endswith("/sendMessage")][-1]
assert r["path"] == "/bot%s/sendMessage" % sys.argv[2], r["path"]
q = urllib.parse.parse_qs(r["body"])
assert q["chat_id"] == ["424242"] and q["text"] == ["botapi sample & text=x"], q
assert q["disable_web_page_preview"] == ["true"] and "parse_mode" not in q, q
PY
grep -q "$TOKEN" "$state_file" && fail botapi-token-in-receipt
grep -q 424242 "$state_file" && fail botapi-chat-in-receipt
stop_pid "$stub_pid"
start_stub "$TG_LOG"
export COCKPIT_TELEGRAM_API_BASE="http://127.0.0.1:${stub_port}"
cockpit notify --check --json | grep -q '"telegram":"ready"' || fail botapi-check-getme

# ---------------------------------------------------------------- redaction
rc=0; out_redact="$(cockpit notify --sink telegram "fail_token_leak" 2>&1)" || rc=$?
[[ "$rc" -eq 3 ]] || fail "redaction-rc $rc"
[[ "$out_redact" == *"telegram:fail:botapi-http-500"* ]] || fail redaction-status "$out_redact"
[[ "$out_redact" == *"boom at /bot***/sendMessage"* ]] || fail redaction-masked "$out_redact"
[[ "$out_redact" != *"$TOKEN"* && "$out_redact" != *"${TOKEN#*:}"* ]] || fail redaction-leak

# ---------------------------------------------------------------- ntfy
unset COCKPIT_TELEGRAM_BOT_TOKEN COCKPIT_TELEGRAM_CHAT_ID
NT_LOG="$FIXTURE_TEST_ROOT/ntfy.jsonl"
stop_pid "$stub_pid"
start_stub "$NT_LOG" --slow 1.5
export COCKPIT_NTFY_SERVER="http://127.0.0.1:${stub_port}" COCKPIT_NTFY_TOPIC="topic-$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
export COCKPIT_NTFY_TOKEN="tk_$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
cockpit notify --sink ntfy --title "Build" --priority high --link https://example.com/run/1 "@/etc/passwd ntfy body" \
  >"$FIXTURE_TEST_ROOT/ntfy.out" 2>&1 &
npid=$!
our_pids+=("$npid")
leaked=0
while kill -0 "$npid" 2>/dev/null; do
  snap="$(ps -axww -o command= 2>/dev/null || true)"
  [[ "$snap" == *"$COCKPIT_NTFY_TOPIC"* || "$snap" == *"$COCKPIT_NTFY_TOKEN"* ]] && leaked=1
  sleep 0.1
done
wait "$npid" || fail ntfy "$(cat "$FIXTURE_TEST_ROOT/ntfy.out")"
[[ "$leaked" -eq 0 ]] || fail ntfy-argv-topic
python3 - "$NT_LOG" "$COCKPIT_NTFY_TOPIC" "$COCKPIT_NTFY_TOKEN" <<'PY' || fail ntfy-request
import json, sys
r = [json.loads(l) for l in open(sys.argv[1])][-1]
h = {k.lower(): v for k, v in r["headers"].items()}
assert r["method"] == "POST" and r["path"] == "/" + sys.argv[2], r["path"]
assert h["title"] == "Build" and h["priority"] == "4" and h["tags"] == "cockpit", h
assert h["click"] == "https://example.com/run/1" and h["authorization"] == "Bearer " + sys.argv[3], h
assert r["body"] == "@/etc/passwd ntfy body\nhttps://example.com/run/1", repr(r["body"])
PY
grep -q "$COCKPIT_NTFY_TOPIC" "$state_file" && fail ntfy-topic-in-receipt
# --via api: the notify key rides a config FD too (sampled against the slow stub)
AK="nk_$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')"
COCKPIT_NOTIFY_URL="http://127.0.0.1:${stub_port}/api/notify" COCKPIT_NOTIFY_KEY="$AK" \
  cockpit notify --via api "api argv probe" >/dev/null 2>&1 &
npid=$!
our_pids+=("$npid")
leaked=0
while kill -0 "$npid" 2>/dev/null; do
  [[ "$(ps -axww -o command= 2>/dev/null || true)" == *"$AK"* ]] && leaked=1
  sleep 0.1
done
wait "$npid" || true
[[ "$leaked" -eq 0 ]] || fail api-client-argv-key
python3 - "$NT_LOG" "$AK" <<'PY' || fail api-client-request
import json, sys
r = [json.loads(l) for l in open(sys.argv[1])][-1]
h = {k.lower(): v for k, v in r["headers"].items()}
assert r["path"] == "/api/notify" and h["authorization"] == "Bearer " + sys.argv[2], r
b = json.loads(r["body"])
assert b["message"] == "api argv probe" and b["title"] == "Cockpit" and b["id"], b
PY
# auto: Telegram before ntfy, never both — hermes ok means ntfy is not called
cat >"$FIXTURE_FAKEBIN/hermes" <<'SH'
#!/usr/bin/env bash
exit "${HERMES_RC:-0}"
SH
chmod +x "$FIXTURE_FAKEBIN/hermes"
before="$(hits "$NT_LOG" POST)"
out="$(cockpit notify "auto order")"
[[ "$out" == *"delivered=telegram sinks=telegram:ok,ntfy:skip:telegram-ok"* ]] || fail ntfy-auto-order "$out"
[[ "$(hits "$NT_LOG" POST)" -eq "$before" ]] || fail ntfy-auto-both
# failed Telegram falls back to ntfy
out="$(HERMES_RC=1 cockpit notify "fallback" 2>/dev/null)"
[[ "$out" == *"delivered=ntfy sinks=telegram:fail:hermes-rc-1,ntfy:ok"* ]] || fail ntfy-fallback "$out"
rm -f "$FIXTURE_FAKEBIN/hermes"
rc=0; out="$(cockpit notify --sink ntfy fail_ntfy 2>&1)" || rc=$?
[[ "$rc" -eq 3 && "$out" == *"ntfy:fail:ntfy-http-500"* && "$out" != *"$COCKPIT_NTFY_TOPIC"* ]] || fail "ntfy-fail $rc $out"
stop_pid "$stub_pid"

# ---------------------------------------------------------------- desktop
if [[ "$(uname -s)" == Darwin ]]; then
  # Real osascript on the macOS runner (no fake on PATH).
  out="$(cockpit notify --sink desktop "mac toast" 2>&1)" || fail desktop-osascript "$out"
  [[ "$out" == *"desktop:ok via osascript"* ]] || fail desktop-osascript-line "$out"
  echo "desktop:ok via osascript"
else
  cat >"$FIXTURE_FAKEBIN/notify-send" <<'SH'
#!/usr/bin/env bash
for a in "$@"; do printf '%s\0' "$a"; done >>"${NOTIFY_SEND_LOG:?}"
SH
  chmod +x "$FIXTURE_FAKEBIN/notify-send"
  export NOTIFY_SEND_LOG="$FIXTURE_TEST_ROOT/notify-send.log"
  : >"$NOTIFY_SEND_LOG"
  rc=0; out="$(cockpit notify --sink desktop "headless toast" 2>/dev/null)" || rc=$?
  [[ "$rc" -eq 3 && "$out" == *"desktop:skip:headless"* && ! -s "$NOTIFY_SEND_LOG" ]] || fail "desktop-headless $rc $out"
  out="$(DISPLAY=:99 cockpit notify --sink desktop --title "Cockpit" "linux toast")" || fail desktop "$out"
  [[ "$out" == *"delivered=desktop"* ]] || fail desktop-line "$out"
  [[ "$(tr '\0' '|' <"$NOTIFY_SEND_LOG")" == "-a|Cockpit|-u|normal|--|Cockpit|linux toast|" ]] ||
    fail desktop-argv "$(tr '\0' '|' <"$NOTIFY_SEND_LOG")"
  rm -f "$FIXTURE_FAKEBIN/notify-send"
fi

# ---------------------------------------------------------------- dedupe-id
start_stub "$NT_LOG"
export COCKPIT_NTFY_SERVER="http://127.0.0.1:${stub_port}"
: >"$NT_LOG"
cockpit notify --dry-run --id rel-230 -- once >/dev/null           # dry runs never dedupe a real send
first="$(cockpit notify --sink ntfy --json --id rel-230 -- once)"
[[ "$(hits "$NT_LOG" POST)" -eq 1 ]] || fail dedupe-first
second="$(cockpit notify --sink ntfy --json --id rel-230 -- once)"
python3 -c 'import json,sys; a=json.loads(sys.argv[1]); b=json.loads(sys.argv[2]); assert b["deduped"] is True and a["deduped"] is False and b["id"]==a["id"]=="rel-230" and b["delivered"]=="ntfy"' \
  "$first" "$second" || fail dedupe "$second"
[[ "$(cockpit notify --sink ntfy --id rel-230 -- once)" == *"deduped=true"* ]] || fail dedupe-line
[[ "$(hits "$NT_LOG" POST)" -eq 1 ]] || fail dedupe-count
stop_pid "$stub_pid"
unset COCKPIT_NTFY_SERVER COCKPIT_NTFY_TOPIC COCKPIT_NTFY_TOKEN

# ---------------------------------------------------------------- api-auth / api-ratelimit / api-no-secret-echo
[[ -n "$node_bin" && -x "$node_bin" ]] || fail "api: node not found (set COCKPIT_TEST_NODE)"
[[ -f "$repo_root/app/dist-server/index.js" ]] || fail "api: app/dist-server missing (pnpm run build:server)"

free_port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }
# start_api LOG ENV... → sets api_port, api_pid (ephemeral loopback port; refuses a foreign listener)
start_api() {
  local log=$1; shift
  api_port="$(free_port)"
  if curl -s -o /dev/null --max-time 1 "http://127.0.0.1:${api_port}/"; then fail "api: port $api_port taken"; fi
  env "$@" COCKPIT_WEB_PORT="$api_port" COCKPIT_NOTIFY_ENV_FILE="$COCKPIT_NOTIFY_ENV_FILE" \
    "$node_bin" "$repo_root/app/dist-server/index.js" >"$log" 2>&1 &
  api_pid=$!
  our_pids+=("$api_pid")
  for _ in $(seq 1 100); do
    kill -0 "$api_pid" 2>/dev/null || fail "api: server exited" "$(cat "$log")"
    grep -q "listening on http://127.0.0.1:${api_port}" "$log" &&
      curl -s -o /dev/null "http://127.0.0.1:${api_port}/api/health" && return 0
    sleep 0.1
  done
  fail "api: server not up" "$(cat "$log")"
}
post() { # post CODEVAR BODYFILE JSON [curl args...]
  local json=$3; local -n _code=$1; shift 3
  _code="$(curl -s -o "$FIXTURE_TEST_ROOT/resp.json" -w '%{http_code}' -X POST -H 'content-type: application/json' "$@" \
    -d "$json" "http://127.0.0.1:${api_port}/api/notify")"
}

KEY="nk_$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
S_TOKEN="$(printf '%s:%s' 7412589630 "AAS$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')")"
S_TOPIC="stopic-$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
SRV_LOG="$FIXTURE_TEST_ROOT/server.log"

# Server A: Hostinger mode, dry-run sinks, every secret present in its env.
start_stub "$FIXTURE_TEST_ROOT/srv-stub.jsonl"   # getMe for /api/notify/status (no live Telegram)
start_api "$SRV_LOG" COCKPIT_HOSTINGER=1 COCKPIT_NOTIFY_KEY="$KEY" COCKPIT_NOTIFY_DRY_RUN=1 \
  COCKPIT_TELEGRAM_API_BASE="http://127.0.0.1:${stub_port}" \
  COCKPIT_TELEGRAM_BOT_TOKEN="$S_TOKEN" COCKPIT_TELEGRAM_CHAT_ID=515151 COCKPIT_NTFY_TOPIC="$S_TOPIC"
post code x '{"message":"x"}'
[[ "$code" == 401 ]] || fail "api-auth no-cred $code"
post code x '{"message":"x"}' -H "Authorization: Bearer wrong-$KEY"
[[ "$code" == 401 ]] || fail "api-auth wrong-key $code"
post code x '{"message":"Cockpit v2.3.0 GTM done","id":"api-1"}' -H "Authorization: Bearer $KEY"
resp="$(cat "$FIXTURE_TEST_ROOT/resp.json")"
[[ "$code" == 200 ]] || fail "api-auth bearer $code" "$resp"
python3 - "$resp" <<'PY' || fail api-auth-receipt "$resp"
import json, sys, hashlib
d = json.loads(sys.argv[1])
assert d["delivered"] == "dry-run" and d["via"] == "api" and d["id"] == "api-1", d
assert d["message_sha256"] == hashlib.sha256(b"Cockpit v2.3.0 GTM done").hexdigest(), d
assert set(d) == {"ts","id","via","title","message_sha256","preview","sinks","delivered","deduped"}, sorted(d)
PY
post code x '{"message":""}' -H "Authorization: Bearer $KEY"; [[ "$code" == 400 ]] || fail "api-validate empty $code"
post code x '{"message":"x","link":"http://a"}' -H "Authorization: Bearer $KEY"; [[ "$code" == 400 ]] || fail "api-validate link $code"
post code x '{"message":"x","sink":"pigeon"}' -H "Authorization: Bearer $KEY"; [[ "$code" == 400 ]] || fail "api-validate sink $code"
st="$(curl -s -H "Authorization: Bearer $KEY" "http://127.0.0.1:${api_port}/api/notify/status")"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert set(d)=={"telegram","ntfy","desktop"} and all(isinstance(v,bool) for v in d.values()) and d["ntfy"] is True and d["telegram"] is True, d' "$st" ||
  fail api-status "$st"
[[ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${api_port}/api/notify/status")" == 401 ]] || fail api-status-401
all_resp="$resp $st"

# exit 4: CLI --via api with a wrong key; exit 0 via api with the right key
rc=0; COCKPIT_NOTIFY_URL="http://127.0.0.1:${api_port}/api/notify" COCKPIT_NOTIFY_KEY="bad-key" \
  cockpit notify --via api "remote" >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 4 ]] || fail "exit-4 rc=$rc"
out="$(COCKPIT_NOTIFY_URL="http://127.0.0.1:${api_port}/api/notify" COCKPIT_NOTIFY_KEY="$KEY" cockpit notify "remote via api")" ||
  fail exit-0-api
[[ "$out" == "notify: delivered=dry-run sinks=dry-run:ok id="* ]] || fail api-cli-line "$out"
all_resp+=" $out"

stop_pid "$api_pid"

# api-ratelimit: fresh server, 10 calls in a burst pass, the 11th within 60 s is 429; CLI maps it to exit 5.
start_api "$FIXTURE_TEST_ROOT/server-rl.log" COCKPIT_HOSTINGER=1 COCKPIT_NOTIFY_KEY="$KEY" COCKPIT_NOTIFY_DRY_RUN=1
codes=""
for i in $(seq 1 11); do
  post c x "{\"message\":\"r$i\"}" -H "Authorization: Bearer $KEY"
  codes+="$c "
  all_resp+=" $(cat "$FIXTURE_TEST_ROOT/resp.json")"
done
[[ "$codes" == "200 200 200 200 200 200 200 200 200 200 429 " ]] || fail "api-ratelimit codes=$codes"
rc=0; COCKPIT_NOTIFY_URL="http://127.0.0.1:${api_port}/api/notify" COCKPIT_NOTIFY_KEY="$KEY" \
  cockpit notify --via api "limited" >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 5 ]] || fail "exit-5 rc=$rc"
stop_pid "$api_pid"

# api-no-secret-echo: responses + server log never carry key/token/topic/chat id
for s in "$KEY" "$S_TOKEN" "${S_TOKEN#*:}" "$S_TOPIC" 515151; do
  [[ "$all_resp" != *"$s"* ]] || fail api-no-secret-echo-response
  cat "$SRV_LOG" "$FIXTURE_TEST_ROOT/server-rl.log" | grep -qF -- "$s" && fail api-no-secret-echo-log
done
cat "$SRV_LOG" "$FIXTURE_TEST_ROOT/server-rl.log" | grep -q Bearer && fail api-no-secret-echo-bearer

# Local trust: honoured only with COCKPIT_LOCAL_TRUST=1 on a loopback peer and never under COCKPIT_HOSTINGER=1.
start_api "$FIXTURE_TEST_ROOT/server-b.log" COCKPIT_LOCAL_TRUST=1 COCKPIT_HOSTINGER=1 COCKPIT_NOTIFY_DRY_RUN=1
post code x '{"message":"x"}'
[[ "$code" == 401 ]] || fail "api-auth local-trust+hostinger $code"
stop_pid "$api_pid"
start_api "$FIXTURE_TEST_ROOT/server-c.log" COCKPIT_LOCAL_TRUST=1 COCKPIT_NOTIFY_DRY_RUN=1
post code x '{"message":"x"}'
[[ "$code" == 200 ]] || fail "api-auth local-trust loopback $code" "$(cat "$FIXTURE_TEST_ROOT/resp.json")"
post code x '{"message":"x"}' -H 'X-Forwarded-For: 203.0.113.9' -H 'Host: cockpit.example.com'
[[ "$code" == 200 ]] || fail "api-auth local-trust header-independent $code"
stop_pid "$api_pid"

echo "notify: ok (cli-contract, exit-codes, hermes, botapi-no-argv-token, ntfy, desktop, dedupe-id, redaction, api-auth, api-ratelimit, api-no-secret-echo)"
