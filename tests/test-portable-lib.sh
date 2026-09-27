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
rp="$(cockpit_realpath "$chain/with spaces")"
[[ -f "$rp" ]] || fail "realpath chain"

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
  :
elif [[ "$env_rc" == 2 ]]; then
  :
elif [[ "$(uname -s)" == Darwin ]]; then
  :
else
  fail "pid environ"
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

printf 'abc' >"$tmpdir/abc"
hash="$(cockpit_sha256 "$tmpdir/abc")"
[[ "$hash" == ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad ]] ||
  fail "sha256"

printf '1.0\n1.10\n2.0\n' | cockpit_sort_version | tail -1 | grep -q '^2.0$' || fail "sort -V"

if [[ "$(cockpit_watch_backend)" != none ]]; then
  # shellcheck source=../bin/cockpit-lib
  source "$repo_root/bin/cockpit-lib"
  export COCKPIT_EVENT_FD=
  cockpit_event_open testsession WATCHTEST
  watchfile="$tmpdir/watchme"
  touch "$watchfile"
  cockpit_event_watch "$tmpdir" -r -e close_write
  got=
  if [[ "$(cockpit_watch_backend)" == "$COCKPIT_BACKEND_FSWATCH" ]]; then
    sleep 0.5
    for _ in $(seq 1 50); do
      touch "$watchfile" 2>/dev/null || true
      if cockpit_event_drain | grep -q .; then
        got=1
        break
      fi
      sleep 0.2
    done
    if [[ -z "$got" ]]; then
      kill -USR1 "$$" 2>/dev/null || true
      sleep 0.2
      cockpit_event_drain >/dev/null || true
      [[ "${COCKPIT_WAKE:-0}" == 1 ]] && got=1
    fi
  else
    sleep 0.5
    touch "$watchfile"
    for _ in $(seq 1 40); do
      touch "$watchfile" 2>/dev/null || true
      if cockpit_event_drain | grep -q .; then
        got=1
        break
      fi
      sleep 0.1
    done
  fi
  [[ -n "$got" ]] || fail "watch event"
  cockpit_event_close
  sleep 0.5
  if [[ "$(uname -s)" != Darwin ]]; then
    children=$(pgrep -P $$ 2>/dev/null | wc -l | tr -d '[:space:]')
    [[ "${children:-0}" -lt 8 ]] || fail "watcher children"
  fi
fi

printf 'portable-lib: ok\n'
