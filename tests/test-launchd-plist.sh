#!/usr/bin/env bash
# C3-next (t1127u) plist contract, runnable on any OS (no launchctl needed):
#   port-numeric   COCKPIT_WEB_PORT reaches the LaunchAgent plist only when it is
#                  1-5 digits; anything else is dropped with a warning and the plist
#                  is byte-identical to the unset-port plist (untrusted input never
#                  reaches the XML).
#   documented-env every env var the plist, the Hostinger systemd unit and
#                  bin/cockpit-web set is named in docs/service-env.md.
# The plist is written by the real cockpit_service_install_launchd with a fake
# launchctl first on PATH and a temp HOME; the real launchctl is never run.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init launchd-plist
unset COCKPIT_WEB_PORT COCKPIT_HOSTINGER COCKPIT_INSTALL_ROOT

failed=()
pass() { printf 'launchd-plist: PASS %s\n' "$1"; }
bad() { printf 'launchd-plist: FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" >&2; failed+=("$1"); }
die() { printf 'launchd-plist: FAIL (%s)\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" >&2; exit 1; }

fake="$FIXTURE_TEST_ROOT/fake-launchctl"
mkdir -p "$fake" "$FIXTURE_TEST_ROOT/bindir"
cat >"$fake/launchctl" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"${FAKE_LAUNCHCTL_LOG:?}"
exit 0
SH
chmod +x "$fake/launchctl"
install -m 0755 "$repo_root/bin/cockpit-web" "$FIXTURE_TEST_ROOT/bindir/cockpit-web"

n=0
# write_plist [PORT_VALUE] → sets plist, errlog (PORT unset when no argument)
write_plist() {
  n=$((n + 1))
  local h="$FIXTURE_TEST_ROOT/h$n"
  mkdir -p "$h"
  errlog="$h/stderr.log"
  if (($#)); then
    env PATH="$fake:$PATH" HOME="$h" FAKE_LAUNCHCTL_LOG="$h/launchctl.log" COCKPIT_WEB_PORT="$1" \
      bash -c 'source "$1/bin/cockpit-portable-lib"; cockpit_service_install_launchd "$2" "$1"' \
      _ "$repo_root" "$FIXTURE_TEST_ROOT/bindir" >"$h/stdout.log" 2>"$errlog" || die "install rc $? (port case $n)" "$(cat "$errlog")"
  else
    env PATH="$fake:$PATH" HOME="$h" FAKE_LAUNCHCTL_LOG="$h/launchctl.log" \
      bash -c 'source "$1/bin/cockpit-portable-lib"; cockpit_service_install_launchd "$2" "$1"' \
      _ "$repo_root" "$FIXTURE_TEST_ROOT/bindir" >"$h/stdout.log" 2>"$errlog" || die "install rc $? (case $n)" "$(cat "$errlog")"
  fi
  grep -q '^bootstrap ' "$h/launchctl.log" || die "fake launchctl not used (case $n)"
  plist="$h/Library/LaunchAgents/com.dezocode.cockpit-web.plist"
  [[ -f "$plist" ]] || die "plist missing (case $n)"
}
# env_json PLIST → the EnvironmentVariables dict as JSON, or "INVALID: ..." when the plist does not parse
env_json() {
  python3 - "$1" <<'PY'
import json, plistlib, sys
try:
    d = plistlib.load(open(sys.argv[1], "rb"))
    print(json.dumps(d["EnvironmentVariables"], sort_keys=True))
except Exception as e:
    print("INVALID: %s" % e)
PY
}

base_keys='["COCKPIT_INSTALL_ROOT", "COCKPIT_WEB_HOST", "PATH"]'
keys_of() { python3 -c 'import json,sys; print(json.dumps(sorted(json.loads(sys.argv[1]))))' "$1" 2>/dev/null || printf '%s' "$1"; }

# ------------------------------------------------------------ unset: no key, no warning
write_plist
j="$(env_json "$plist")"
if [[ "$(keys_of "$j")" == "$base_keys" && ! -s "$errlog" ]]; then pass "port-unset-no-key"; else bad "port-unset-no-key" "$j $(cat "$errlog")"; fi
command -v plutil >/dev/null 2>&1 && { plutil -lint "$plist" >/dev/null || bad "plutil-lint-unset"; }
# normalized PLIST → content with this case's temp HOME replaced, for byte comparison
normalized() { local h="${1%/Library/LaunchAgents/*}"; python3 -c 'import sys; print(open(sys.argv[1]).read().replace(sys.argv[2], "@HOME@"))' "$1" "$h"; }
baseline="$(normalized "$plist")"

# ------------------------------------------------------------ numeric: carried verbatim
for v in 8787 49152 1; do
  write_plist "$v"
  j="$(env_json "$plist")"
  got="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("COCKPIT_WEB_PORT","<absent>"))' "$j" 2>/dev/null || echo "$j")"
  if [[ "$got" == "$v" && ! -s "$errlog" ]]; then pass "port-numeric-kept ($v)"; else bad "port-numeric-kept ($v)" "got=$got err=$(cat "$errlog")"; fi
done

# ------------------------------------------------------------ non-numeric: never reaches the plist
nonnum=('8787;x' 'abc' '<string>' '8787</string><key>X</key><string>1' '123456' ' 8787' '8787 ' $'8787\nx' '$(id)' '-1' '0x1F' '87&87')
for v in "${nonnum[@]}"; do
  write_plist "$v"
  j="$(env_json "$plist")"
  shown="$(printf '%q' "$v")"
  if [[ "$j" == INVALID:* ]]; then
    bad "port-non-numeric-dropped ($shown)" "plist no longer parses: $j"
  elif [[ "$(keys_of "$j")" != "$base_keys" ]]; then
    bad "port-non-numeric-dropped ($shown)" "env keys: $(keys_of "$j")"
  elif ! grep -q '^launchd: ignoring non-numeric COCKPIT_WEB_PORT$' "$errlog"; then
    bad "port-non-numeric-dropped ($shown)" "no 'ignoring non-numeric' warning: $(cat "$errlog")"
  elif [[ "$(normalized "$plist")" != "$baseline" ]]; then
    bad "port-non-numeric-dropped ($shown)" "plist differs from the unset-port plist"
  else
    pass "port-non-numeric-dropped ($shown)"
  fi
done

# ------------------------------------------------------------ documented-env
doc="$repo_root/docs/service-env.md"
[[ -f "$doc" ]] || die "docs/service-env.md missing"
# Documented names = backticked first-column entries of the table rows.
documented="$(awk -F'|' '/^\| `[A-Z_][A-Z0-9_]*` \|/ { gsub(/[` ]/, "", $2); print $2 }' "$doc" | sort -u)"
[[ -n "$documented" ]] || die "no variables parsed from docs/service-env.md"
is_documented() { grep -qx -- "$1" <<<"$documented"; }
check_set() {  # SOURCE NAMES...
  local src=$1 name missing=(); shift
  for name in "$@"; do is_documented "$name" || missing+=("$name"); done
  if ((${#missing[@]})); then bad "documented-env ($src)" "undocumented: ${missing[*]}"; else pass "documented-env ($src: $*)"; fi
}
write_plist 8787
# shellcheck disable=SC2046
check_set plist $(python3 -c 'import json,sys; print(" ".join(sorted(json.loads(sys.argv[1]))))' "$(env_json "$plist")")
# Unit and launcher are read as data (never sourced/executed here).
# shellcheck disable=SC2046
check_set systemd-unit $(sed -n 's/^Environment="\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$repo_root/packaging/systemd/cockpit-web.service" | sort -u)
# shellcheck disable=SC2046
check_set bin/cockpit-web $(sed -n 's/^[[:space:]]*export \([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$repo_root/bin/cockpit-web" | sort -u)
# shellcheck disable=SC2046
check_set scripts/start-dist-server.sh $(sed -n 's/^[[:space:]]*export \([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$repo_root/scripts/start-dist-server.sh" | sort -u)

if ((${#failed[@]})); then
  printf 'launchd-plist: FAIL (%s)\n' "${failed[*]}"
  exit 1
fi
echo "launchd-plist: ok (port unset/numeric/${#nonnum[@]} non-numeric, documented-env)"
