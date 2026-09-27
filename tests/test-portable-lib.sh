#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../bin/cockpit-portable-lib
source "$repo_root/bin/cockpit-portable-lib"

fail() {
  printf 'portable-lib: FAIL (%s)\n' "$1"
  exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

f="$tmpdir/five"
printf 'hello' >"$f"
sleep 1
line="$(cockpit_stat_mtime_size "$f")"
read -r _path mtime size <<<"$line"
[[ "$size" == 5 ]] || fail "stat size"
now=$(date +%s)
((mtime >= now - 5 && mtime <= now + 5)) || fail "stat mtime"

chmod 640 "$f"
[[ "$(cockpit_stat_mode "$f")" == 640 ]] || fail "stat mode"

dst="$tmpdir/dst"
cp "$f" "$dst"
chmod 600 "$dst"
cockpit_copy_mode "$f" "$dst"
[[ "$(cockpit_stat_mode "$dst")" == 640 ]] || fail "copy_mode"

chain="$tmpdir/chain"
mkdir -p "$chain/a/b"
printf 'x' >"$chain/a/b/target"
ln -sf b/target "$chain/a/link1"
ln -sf a/link1 "$chain/link2"
ln -sf link2 "$chain/with spaces"
ln -sf ../target "$chain/a/b/space target"
rp="$(cockpit_realpath "$chain/with spaces")"
want="$(cd -P -- "$chain/a/b" && pwd -P)/target"
[[ "$rp" == "$want" ]] || fail "realpath chain ($rp != $want)"
mkdir -p "$tmpdir/dir with spaces"
printf 'y' >"$tmpdir/dir with spaces/f"
ln -sf "dir with spaces/f" "$tmpdir/sp-link"
[[ "$(cockpit_realpath "$tmpdir/sp-link")" == "$(cd -P -- "$tmpdir/dir with spaces" && pwd -P)/f" ]] ||
  fail "realpath spaces"

cockpit_pid_alive "$$" || fail "pid alive self"
dead_pid="$(awk '/^PidMax:/{print $2}' /proc/sys/kernel/pid_max 2>/dev/null || echo 999999)"
while cockpit_pid_alive "$dead_pid"; do
  dead_pid=$((dead_pid - 1))
done
cockpit_pid_alive "$dead_pid" && fail "dead pid"

comm="$(cockpit_pid_comm $$)"
[[ "$comm" == *bash* ]] || fail "pid comm"

ppid="$(cockpit_pid_ppid $$)"
[[ "$ppid" == "$PPID" ]] || fail "pid ppid"

(
  export FOO=bar
  sleep 2
) &
child=$!
set +e
env_blob="$(cockpit_pid_environ "$child" 2>/dev/null)"
env_rc=$?
set -e
if grep -q '^FOO=bar$' <<<"$env_blob"; then
  printf 'pid_environ: FOO=bar (rc %s)\n' "$env_rc"
elif [[ "$env_rc" == 2 ]]; then
  printf 'pid_environ: unsupported (rc 2) on %s\n' "$(uname -s)"
else
  fail "pid environ (rc $env_rc)"
fi
wait "$child" 2>/dev/null || true

start=$(date +%s)
set +e
cockpit_timeout 0.5 sleep 5
rc=$?
set -e
end=$(date +%s)
[[ "$rc" == 124 ]] || fail "timeout rc"
((end - start < 2)) || fail "timeout duration"

# Watchdog contract (the only path on stock macOS): caller stdin reaches the
# command, and $(...) returns as soon as the command exits.
[[ "$(printf 'in\n' | cockpit_timeout 5 cat)" == in ]] || fail "timeout stdin"
start=$(date +%s)
out="$(cockpit_timeout 5 printf 'fast')"
end=$(date +%s)
[[ "$out" == fast ]] || fail "timeout output"
((end - start < 2)) || fail "timeout blocks command substitution"
set +e
cockpit_timeout 5 false
rc=$?
set -e
[[ "$rc" == 1 ]] || fail "timeout passthrough rc ($rc)"

[[ "$(cockpit_utc_epoch 2000-01-01T00:00:00Z)" == 946684800 ]] || fail "utc_epoch Z"
[[ "$(cockpit_utc_epoch 2000-01-01T00:00:00.123456Z)" == 946684800 ]] || fail "utc_epoch fraction"
[[ "$(cockpit_utc_epoch 2000-01-01T05:30:00+05:30)" == 946684800 ]] || fail "utc_epoch offset"
[[ "$(cockpit_utc_epoch 2099-01-01T00:00:00Z)" == 4070908800 ]] || fail "utc_epoch 2099"
if cockpit_utc_epoch not-a-date >/dev/null 2>&1; then fail "utc_epoch garbage"; fi

# Login-shell probes keep the caller's PATH precedence (macOS path_helper
# reorders PATH in /etc/profile; elsewhere the command is passed unchanged).
[[ "$(_cockpit_has_path_helper=0 cockpit_login_command 'echo x')" == 'echo x' ]] || fail "login_command passthrough"
if [[ "$_cockpit_has_path_helper" == 1 ]]; then
  mkdir -p "$tmpdir/fakebin"
  printf '#!/bin/sh\necho fake-gh\n' >"$tmpdir/fakebin/gh"
  chmod +x "$tmpdir/fakebin/gh"
  login_out="$(
    PATH="$tmpdir/fakebin:$PATH"
    bash -lc "$(cockpit_login_command 'gh')" 2>/dev/null
  )" || login_out=''
  [[ "$login_out" == fake-gh ]] || fail "login_command PATH precedence ($login_out)"
  printf 'login shell: path_helper=1, caller PATH precedence kept\n'
else
  printf 'login shell: path_helper=0, command passed through unchanged\n'
fi

printf 'abc' >"$tmpdir/abc"
hash="$(cockpit_sha256 "$tmpdir/abc")"
[[ "$hash" == ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad ]] ||
  fail "sha256"

printf '1.0\n1.10\n2.0\n' | cockpit_sort_version | tail -1 | grep -q '^2.0$' || fail "sort -V"

backend="$(cockpit_watch_backend)"
printf 'watch backend: %s\n' "$backend"
if [[ "$backend" == none ]]; then
  fail "no watch backend (install fswatch or inotify-tools)"
fi
# shellcheck source=../bin/cockpit-lib
source "$repo_root/bin/cockpit-lib"
export COCKPIT_EVENT_FD=
wdir="$tmpdir/watch"
mkdir -p "$wdir/.git"
children_before=$(pgrep -P $$ 2>/dev/null | wc -l | tr -d '[:space:]')
cockpit_event_open testsession WATCHTEST
cockpit_event_watch "$wdir" -r -e close_write,moved_to,create --exclude "$cockpit_noise_exclude"
sleep 1 # watcher warm-up (FSEvents stream start); not part of the 3 s budget
edited="$wdir/edited.txt"
printf 'x' >"$edited"
want="$(cockpit_realpath "$edited")"
got='' saw_git='' events=''
t_end=$(($(date +%s) + 3))
while (($(date +%s) <= t_end)); do
  printf 'x' >"$wdir/.git/x"
  while IFS= read -r -t 0.5 -u "$COCKPIT_EVENT_FD" ev; do
    events+="$ev"$'\n'
    [[ "$ev" == */.git/* ]] && saw_git=1
    [[ "$ev" == "$want" ]] && got=1
  done
  [[ -n "$got" ]] && break
  printf 'x' >>"$edited"
done
# Keep reading briefly so a late .git event would still be caught.
while IFS= read -r -t 0.7 -u "$COCKPIT_EVENT_FD" ev; do
  events+="$ev"$'\n'
  [[ "$ev" == */.git/* ]] && saw_git=1
done
[[ -n "$got" ]] || fail "watch event path != $want within 3s (got: ${events//$'\n'/ })"
[[ -z "$saw_git" ]] || fail "watch --exclude leaked .git/x"
printf 'watch: %s event == realpath (%s)\n' "$backend" "$want"
cockpit_event_close
sleep 0.5
leftover="$(pgrep -f -- "$wdir" 2>/dev/null || true)"
[[ -z "$leftover" ]] || fail "watcher processes alive after close: $leftover"
children_after=$(pgrep -P $$ 2>/dev/null | wc -l | tr -d '[:space:]')
((children_after <= children_before)) ||
  fail "watcher children after close ($children_after > $children_before)"
printf 'watch: close left 0 watcher processes\n'

printf 'portable-lib: ok\n'
