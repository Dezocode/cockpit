#!/usr/bin/env bash
# C3-next (t1127u) runtime/config-is-data: COCKPIT_HOSTINGER is a mode toggle that
# defaults OFF. Only the Hostinger systemd unit sets it.
#   local-launch-*     bin/cockpit-web with COCKPIT_HOSTINGER unset: health says local,
#                      loopback notify under COCKPIT_LOCAL_TRUST=1 gets 200 (curl + CLI)
#   explicit-*         COCKPIT_HOSTINGER=1 passed explicitly still means Hostinger (401)
#   plist-*            the LaunchAgent plist never carries COCKPIT_HOSTINGER
#   unit-/installer-*  the Hostinger unit + install script still set it to 1
#   must-absent-*      no launcher/unit defaults it to 1 (probe + negative twin + mutants)
#   docs-*             docs/notify.md names the unit that sets it
# Ports: each server gets an ephemeral 127.0.0.1 port picked here (refused if held).
# Only the PID this script started is stopped; never anything found by port or name.
# The plist is written with a fake launchctl first on PATH: the real one is never run.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
node_bin="${COCKPIT_TEST_NODE:-$(command -v node || true)}"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init hostinger-default

child=""
stop_child() {
  [[ -n "$child" ]] || return 0
  kill "$child" 2>/dev/null || true
  wait "$child" 2>/dev/null || true
  child=""
}
trap 'stop_child; fixture_cleanup' EXIT

failed=()
pass() { printf 'hostinger-default: PASS %s\n' "$1"; }
bad() { printf 'hostinger-default: FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" >&2; failed+=("$1"); }
check() { local label=$1; shift; if "$@"; then pass "$label"; else bad "$label"; fi; }
absent() { local label=$1 pat=$2 file=$3; if grep -q -- "$pat" "$file"; then bad "$label" "$(grep -n -- "$pat" "$file")"; else pass "$label"; fi; }
die() { printf 'hostinger-default: FAIL (%s)\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" >&2; exit 1; }

command -v rg >/dev/null 2>&1 || die "rg not found (the must_absent probe is fail-closed)"
[[ -n "$node_bin" && -x "$node_bin" ]] || die "node not found (set COCKPIT_TEST_NODE)"
[[ -f "$repo_root/app/dist-server/index.js" ]] || die "app/dist-server missing (pnpm run build:server)"
unset COCKPIT_HOSTINGER COCKPIT_LOCAL_TRUST COCKPIT_NOTIFY_KEY COCKPIT_NOTIFY_URL COCKPIT_NOTIFY_DRY_RUN \
  COCKPIT_INSTALL_ROOT COCKPIT_WEB_PORT COCKPIT_WEB_HOST
export COCKPIT_NOTIFY_ENV_FILE="$FIXTURE_TEST_ROOT/no-notify.env"  # never read the host's /etc file
node_dir="$(dirname -- "$node_bin")"

free_port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }

# launch LABEL ENV... → bin/cockpit-web (exec's node, so $! is the server) on its own port
launch() {
  local label=$1; shift
  port="$(free_port)"
  if curl -s -o /dev/null --max-time 1 "http://127.0.0.1:${port}/"; then die "port $port taken"; fi
  log="$FIXTURE_TEST_ROOT/$label.log"
  env PATH="$node_dir:$PATH" "$@" COCKPIT_WEB_PORT="$port" COCKPIT_LOCAL_TRUST=1 COCKPIT_NOTIFY_DRY_RUN=1 \
    "$repo_root/bin/cockpit-web" >"$log" 2>&1 &
  child=$!
  for _ in $(seq 1 100); do
    kill -0 "$child" 2>/dev/null || die "$label: cockpit-web exited" "$(cat "$log")"
    curl -s -o /dev/null "http://127.0.0.1:${port}/api/health" && return 0
    sleep 0.1
  done
  die "$label: cockpit-web not up on 127.0.0.1:$port" "$(cat "$log")"
}
health_mode() {
  curl -s "http://127.0.0.1:${port}/api/health" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["checks"]["hostinger"])'
}
notify_code() {
  curl -s -o "$FIXTURE_TEST_ROOT/resp.json" -w '%{http_code}' -H 'Content-Type: application/json' \
    -d '{"message":"c3-next local-trust"}' "http://127.0.0.1:${port}/api/notify"
}
cli_rc() {
  local rc=0
  COCKPIT_NOTIFY_URL="http://127.0.0.1:${port}/api/notify" cockpit notify --via api "c3-next cli" \
    >"$FIXTURE_TEST_ROOT/cli.out" 2>&1 || rc=$?
  printf '%s' "$rc"
}

# ------------------------------------------------------------ local launch (unset)
launch local
mode="$(health_mode)"; code="$(notify_code)"; crc="$(cli_rc)"
printf 'hostinger-default: local launch pid=%s port=%s checks.hostinger=%s notify=%s cli_rc=%s\n' \
  "$child" "$port" "$mode" "$code" "$crc"
check local-launch-health-not-hostinger test "$mode" = local
check local-trust-notify-200 test "$code" = 200
check local-trust-cli-rc0 test "$crc" = 0
stop_child

# ------------------------------------------------------------ explicit Hostinger mode
launch explicit COCKPIT_HOSTINGER=1
mode="$(health_mode)"; code="$(notify_code)"
printf 'hostinger-default: explicit COCKPIT_HOSTINGER=1 pid=%s port=%s checks.hostinger=%s notify=%s\n' \
  "$child" "$port" "$mode" "$code"
check explicit-hostinger-health-configured test "$mode" = configured
check explicit-hostinger-notify-401 test "$code" = 401
stop_child

# ------------------------------------------------------------ LaunchAgent plist
fake="$FIXTURE_TEST_ROOT/fake-launchctl"
mkdir -p "$fake" "$FIXTURE_TEST_ROOT/bindir"
cat >"$fake/launchctl" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"${FAKE_LAUNCHCTL_LOG:?}"
exit 0
SH
chmod +x "$fake/launchctl"
install -m 0755 "$repo_root/bin/cockpit-web" "$FIXTURE_TEST_ROOT/bindir/cockpit-web"
# write_plist NAME ENV... → prints the plist path (HOME is a temp dir per call)
write_plist() {
  local name=$1; shift
  local h="$FIXTURE_TEST_ROOT/plist-$name"
  mkdir -p "$h"
  env PATH="$fake:$node_dir:$PATH" HOME="$h" FAKE_LAUNCHCTL_LOG="$h/launchctl.log" "$@" \
    bash -c 'source "$1/bin/cockpit-portable-lib"; cockpit_service_install_launchd "$2" "$1"' \
    _ "$repo_root" "$FIXTURE_TEST_ROOT/bindir" >"$h/out.log" 2>&1 || die "plist $name: install rc $?" "$(cat "$h/out.log")"
  grep -q '^bootstrap ' "$h/launchctl.log" || die "plist $name: fake launchctl not used"
  printf '%s' "$h/Library/LaunchAgents/com.dezocode.cockpit-web.plist"
}
plist_keys() {
  python3 -c 'import plistlib,sys; print(" ".join(sorted(plistlib.load(open(sys.argv[1],"rb"))["EnvironmentVariables"])))' "$1"
}
p_unset="$(write_plist unset)"
p_set="$(write_plist set COCKPIT_HOSTINGER=1)"
printf 'hostinger-default: plist env keys (unset): %s\n' "$(plist_keys "$p_unset")"
absent plist-no-hostinger COCKPIT_HOSTINGER "$p_unset"
absent plist-no-hostinger-even-when-caller-sets-it COCKPIT_HOSTINGER "$p_set"

# ------------------------------------------------------------ Hostinger path keeps it (read as data)
unit="$repo_root/packaging/systemd/cockpit-web.service"
check unit-sets-hostinger-1 test "$(grep -c '^Environment=COCKPIT_HOSTINGER=1$' "$unit")" = 1
check unit-sets-no-other-hostinger-value test "$(grep -c 'COCKPIT_HOSTINGER' "$unit")" = 1
inst="$repo_root/scripts/install-hostinger.sh"
check installer-exports-hostinger-1 grep -q '^export COCKPIT_HOSTINGER=1$' "$inst"
check installer-installs-that-unit grep -q 'packaging/systemd/cockpit-web.service' "$inst"

# ------------------------------------------------------------ must_absent probe
# Any "defaults to 1 / set to 1 / plist key" form in launchers and units. The two
# explicit Hostinger lines (unit Environment= and install-hostinger.sh export) are
# the only allowed hits, matched by file and full line. Markdown and shell comment
# lines are prose, not configuration, and are not scanned.
hostinger_probe() {  # ROOT → offending lines on stdout; rc 0 clean, 1 findings, 2 scanner error
  local root=$1 out rc=0 paths=()
  local p
  for p in bin packaging scripts install.sh; do [[ -e "$root/$p" ]] && paths+=("$p"); done
  ((${#paths[@]})) || return 2
  out="$(cd "$root" && rg -n --no-heading -g '!*.md' \
    -e 'COCKPIT_HOSTINGER(:?-|:?=)["'"'"']?1\b' \
    -e 'COCKPIT_HOSTINGER["'"'"']?[[:space:]]*:[[:space:]]*["'"'"']?1\b' \
    -e '<key>COCKPIT_HOSTINGER</key>' -- "${paths[@]}")" || rc=$?
  ((rc >= 2)) && { printf 'rg exited %s\n' "$rc"; return 2; }
  out="$(printf '%s\n' "$out" | grep -Ev \
    -e '^packaging/systemd/cockpit-web\.service:[0-9]+:Environment=COCKPIT_HOSTINGER=1$' \
    -e '^scripts/install-hostinger\.sh:[0-9]+:export COCKPIT_HOSTINGER=1$' \
    -e '^[^:]+:[0-9]+:[[:space:]]*#' \
    -e '^$' || true)"
  [[ -z "$out" ]] && return 0
  printf '%s\n' "$out"
  return 1
}
prc=0; pout="$(hostinger_probe "$repo_root")" || prc=$?
check must-absent-repo-clean test "$prc" = 0
[[ "$prc" == 0 ]] || printf '%s\n' "$pout" >&2

# Proctor's minted config-is-data probe (proctor-t1127u-C3-mint-probes.txt (3)), verbatim.
proctor3() {  # ROOT → rc 0 match (finding), 1 clean, >=2 error; paths: bin install.sh scripts packaging
  local p paths=()
  for p in bin install.sh scripts packaging; do [[ -e "$1/$p" ]] && paths+=("$p"); done
  (cd "$1" && rg -n -P '\$\{COCKPIT_[A-Z_]*(HOSTINGER|LOCAL_TRUST|INSECURE|NO_AUTH|ALLOW_[A-Z_]+):-1\}|<key>COCKPIT_[A-Z_]*(HOSTINGER|LOCAL_TRUST|INSECURE|NO_AUTH)</key>\s*$' \
    "${paths[@]}")
}
p3rc=0; p3out="$(proctor3 "$repo_root")" || p3rc=$?
check must-absent-proctor-probe3-clean test "$p3rc" = 1
[[ "$p3rc" == 1 ]] || printf '%s\n' "$p3out" >&2

# Negative twin: a static correct-code fixture (independent of the tree under test) must
# not match: the documented Hostinger unit line, the installer export, a launcher that
# only inherits, and pure reads.
twin="$FIXTURE_TEST_ROOT/twin"
mkdir -p "$twin/bin" "$twin/packaging/systemd" "$twin/scripts"
cat >"$twin/bin/cockpit-web" <<'SH'
export COCKPIT_WEB_PORT="${COCKPIT_WEB_PORT:-8787}"
export COCKPIT_WEB_HOST="${COCKPIT_WEB_HOST:-127.0.0.1}"
exec node "$dist"
SH
printf '[Service]\nEnvironment=COCKPIT_INSTALL_ROOT=/opt/cockpit\nEnvironment=COCKPIT_HOSTINGER=1\nEnvironment=COCKPIT_WEB_PORT=8787\n' \
  >"$twin/packaging/systemd/cockpit-web.service"
printf 'COCKPIT_INSTALL_ROOT="${COCKPIT_INSTALL_ROOT:-/opt/cockpit}"\nexport COCKPIT_HOSTINGER=1\n' >"$twin/scripts/install-hostinger.sh"
cat >"$twin/bin/reads" <<'SH'
[[ "${COCKPIT_HOSTINGER:-0}" == 1 ]] && echo hostinger
[[ "${COCKPIT_HOSTINGER:-}" == 1 ]] && echo hostinger
const hostinger = process.env.COCKPIT_HOSTINGER === "1";
env -u COCKPIT_HOSTINGER node app/dist-server/index.js
COCKPIT_HOSTINGER=10
# callers pass COCKPIT_HOSTINGER=1 explicitly (comment: prose, not config)
SH
trc=0; tout="$(hostinger_probe "$twin")" || trc=$?
check must-absent-negative-twin-clean test "$trc" = 0
[[ "$trc" == 0 ]] || printf '%s\n' "$tout" >&2

# Positive mutants: each must be caught, naming its own file.
mutant() {  # NAME RELPATH LINE
  local m="$FIXTURE_TEST_ROOT/mut-$1" rc=0 out
  rm -rf "$m"; cp -R "$twin" "$m"
  mkdir -p "$m/$(dirname -- "$2")"
  printf '%s\n' "$3" >>"$m/$2"
  out="$(hostinger_probe "$m")" || rc=$?
  if [[ "$rc" == 1 && "$out" == *"$2:"* ]]; then pass "must-absent-catches-$1"; else bad "must-absent-catches-$1" "rc=$rc out=$out"; fi
}
t3rc=0; proctor3 "$twin" >/dev/null || t3rc=$?
check must-absent-proctor-probe3-negative-twin-clean test "$t3rc" = 1
mutant launcher-default bin/cockpit-web 'export COCKPIT_HOSTINGER="${COCKPIT_HOSTINGER:-1}"'
mutant launcher-assign-default scripts/start-dist-server.sh ': "${COCKPIT_HOSTINGER:=1}"'
mutant launcher-hardcode bin/cockpit-web 'export COCKPIT_HOSTINGER=1'
mutant plist-key bin/cockpit-portable-lib '    <key>COCKPIT_HOSTINGER</key>'
mutant other-unit packaging/systemd/cockpit-web-local.service 'Environment=COCKPIT_HOSTINGER=1'
mutant json-env packaging/env.json '{"COCKPIT_HOSTINGER": "1"}'

# ------------------------------------------------------------ docs match the code
notify_line="$(grep -n 'COCKPIT_HOSTINGER=1. disables local trust' "$repo_root/docs/notify.md" || true)"
absent docs-notify-no-stale-claim 'no server unit sets it' "$repo_root/docs/notify.md"
check docs-notify-names-the-unit grep -q 'packaging/systemd/cockpit-web.service' "$repo_root/docs/notify.md"
check docs-notify-has-hostinger-line test -n "$notify_line"

if ((${#failed[@]})); then
  printf 'hostinger-default: FAIL (%s)\n' "${failed[*]}"
  exit 1
fi
echo "hostinger-default: ok (local launch local+200, explicit 1 -> 401, plist clean, unit+installer set 1, must_absent + twin + 6 mutants, docs)"
