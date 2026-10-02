#!/usr/bin/env bash
set -euo pipefail
# launchd user agent: plist lint, bootstrap, /api/health, bootout, idempotent
# re-install. The agent is pointed at an ephemeral 127.0.0.1 port this test
# picked (COCKPIT_WEB_PORT is carried into the plist); only the job this test
# bootstrapped is ever stopped (bootout of its label + wait on its own PID),
# never anything found by port or process name.

if ! command -v launchctl >/dev/null 2>&1; then
  printf 'launchd: skip (no launchctl)\n'
  exit 0
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
label=com.dezocode.cockpit-web
uid="$(id -u)"
fail() {
  printf 'launchd: FAIL (%s)\n' "$1"
  [[ -f "${HOME}/Library/Logs/cockpit-web.log" ]] && sed -n '1,80p' "${HOME}/Library/Logs/cockpit-web.log" >&2
  exit 1
}

home="$(mktemp -d)"
agent_pid=""
unload_ours() {
  launchctl bootout "gui/$uid/$label" 2>/dev/null || launchctl bootout "user/$uid/$label" 2>/dev/null || :
  if [[ -n "$agent_pid" ]]; then
    for _ in $(seq 1 40); do kill -0 "$agent_pid" 2>/dev/null || break; sleep 0.25; done
  fi
}
trap 'unload_ours; rm -rf "$home"' EXIT
export HOME="$home"

port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
if curl -s -o /dev/null --max-time 1 "http://127.0.0.1:${port}/"; then fail "port $port taken"; fi
export COCKPIT_WEB_PORT="$port"

install_agent() {
  PATH="$repo_root/bin:$PATH" COCKPIT_INSTALL_SERVICE=1 COCKPIT_INSTALL_WEB_BUILD=0 SHELL=/bin/bash \
    /bin/bash "$repo_root/install.sh" </dev/null >"$home/install.log" 2>&1 || fail "install rc $?"
  grep '^launchd: ' "$home/install.log" | sed 's/^/launchd: install: /'
}

wait_health() {
  for _ in $(seq 1 80); do
    curl -sf "http://127.0.0.1:${port}/api/health" >/dev/null 2>&1 && return 0
    sleep 0.25
  done
  fail "health on 127.0.0.1:${port} ($1)"
}

job_pid() {
  local domain out
  for domain in "gui/$uid" "user/$uid"; do
    out="$(launchctl print "$domain/$label" 2>/dev/null)" || continue
    awk '$1 == "pid" && $2 == "=" { print $3; exit }' <<<"$out"
    return 0
  done
}

install_agent
plist="${HOME}/Library/LaunchAgents/${label}.plist"
[[ -f "$plist" ]] || fail "plist missing"
plutil -lint "$plist" >/dev/null || fail "plist lint"
[[ "$(plutil -extract EnvironmentVariables.COCKPIT_WEB_HOST raw "$plist")" == 127.0.0.1 ]] || fail "plist COCKPIT_WEB_HOST"
[[ "$(plutil -extract EnvironmentVariables.COCKPIT_WEB_PORT raw "$plist")" == "$port" ]] || fail "plist COCKPIT_WEB_PORT"
# A LaunchAgent is a local launch: never Hostinger mode (docs/service-env.md).
if plutil -extract EnvironmentVariables.COCKPIT_HOSTINGER raw "$plist" >/dev/null 2>&1; then fail "plist sets COCKPIT_HOSTINGER"; fi
wait_health first
mode="$(curl -s "http://127.0.0.1:${port}/api/health" | python3 -c 'import json,sys; print(json.load(sys.stdin)["checks"]["hostinger"])')"
printf 'launchd: health checks.hostinger=%s\n' "$mode"
[[ "$mode" == local ]] || fail "launchd agent reports checks.hostinger=$mode (want local)"
agent_pid="$(job_pid)"
[[ "$agent_pid" =~ ^[0-9]+$ ]] || fail "agent pid"
listen="$(lsof -nP -a -p "$agent_pid" -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || :)"
printf 'launchd: listen (agent pid %s):\n%s\n' "$agent_pid" "$listen"
grep -q "127.0.0.1:${port}" <<<"$listen" || fail "agent not on 127.0.0.1:${port}"
if grep -Eq "(\\*|0\\.0\\.0\\.0|\\[::\\]):${port}" <<<"$listen"; then fail "agent listens beyond loopback"; fi

unload_ours
kill -0 "$agent_pid" 2>/dev/null && fail "agent pid $agent_pid survived bootout"

install_agent
wait_health "re-install"
agent_pid="$(job_pid)"
unload_ours

printf 'launchd: ok (plist lint, bootstrap, /api/health, local mode)\n'
