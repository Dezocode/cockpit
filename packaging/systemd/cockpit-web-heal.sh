#!/usr/bin/env bash
# Pre-start heal for cockpit-web — verify install root, build artifacts, node.
# Install root: /opt/cockpit ONLY — never /root/.grok or saul-go.
#
# Port: a listener on $COCKPIT_WEB_PORT is stopped only when its command line is
# cockpit-web, or node running app/dist-server/index.js, at a path under the
# install root. Any other holder is named (pid + command line) and heal exits 1
# without signalling it; a holder heal cannot identify is refused the same way.
set -euo pipefail

COCKPIT_INSTALL_ROOT="${COCKPIT_INSTALL_ROOT:-/opt/cockpit}"
APP="$COCKPIT_INSTALL_ROOT/app"
PORT="${COCKPIT_WEB_PORT:-8787}"

[[ -d "$COCKPIT_INSTALL_ROOT" ]] || { echo "heal: missing $COCKPIT_INSTALL_ROOT"; exit 1; }
[[ -f "$APP/dist-server/index.js" ]] || { echo "heal: missing dist-server — run install-hostinger.sh"; exit 1; }
[[ -f "$APP/dist/index.html" ]] || { echo "heal: missing web dist"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "heal: node not found"; exit 1; }

# Fail-closed: refuse Saul/grok local runtime paths as install root
case "$COCKPIT_INSTALL_ROOT" in
  /root/.grok*|*/saul-go*) echo "heal: DENY install root $COCKPIT_INSTALL_ROOT"; exit 1 ;;
esac

if ! [[ "$PORT" =~ ^[0-9]{1,5}$ ]] || ((10#$PORT < 1 || 10#$PORT > 65535)); then
  printf 'heal: invalid COCKPIT_WEB_PORT %q\n' "$PORT" >&2
  exit 1
fi
PORT=$((10#$PORT))
root_real="$(cd -P -- "$COCKPIT_INSTALL_ROOT" && pwd -P)"

refuse() { printf 'heal: REFUSE %s\n' "$1" >&2; }

# A foreign command line is untrusted text: control bytes are shown as '?'.
printable() {
  local s=$1
  printf '%s' "${s//[[:cntrl:]]/?}"
}

# read_argv PID: sets argv[] to the process's argument vector (empty if gone).
argv=()
read_argv() {
  local a line
  argv=()
  if [[ -r "/proc/$1/cmdline" ]]; then
    while IFS= read -r -d '' a || [[ -n "$a" ]]; do
      argv+=("$a")
    done <"/proc/$1/cmdline"
  else
    line="$(ps -ww -o command= -p "$1" 2>/dev/null)" || return 0
    read -r -a argv <<<"$line"
  fi
}

proc_cwd() {
  local line
  if [[ -e "/proc/$1/cwd" ]]; then
    readlink "/proc/$1/cwd"
    return
  fi
  command -v lsof >/dev/null 2>&1 || return 1
  line="$(lsof -a -nP -p "$1" -d cwd -Fn 2>/dev/null | grep '^n/')" || return 1
  printf '%s\n' "${line#n}"
}

# under_root PID PATH SUFFIX: PATH (relative paths resolve against the
# process's cwd) is canonically inside the install root and ends in SUFFIX.
under_root() {
  local pid=$1 p=$2 suffix=$3 cwd dir canon
  if [[ "$p" != /* ]]; then
    cwd="$(proc_cwd "$pid")" || return 1
    [[ "$cwd" == /* ]] || return 1
    p="$cwd/$p"
  fi
  dir="$(cd -P -- "$(dirname -- "$p")" 2>/dev/null && pwd -P)" || return 1
  canon="$dir/$(basename -- "$p")"
  [[ "$canon" == "$root_real"/* && "$canon" == */"$suffix" ]]
}

is_ours() {
  local pid=$1 base i n=${#argv[@]}
  ((n)) || return 1
  base=${argv[0]##*/}
  case "$base" in
    cockpit-web) under_root "$pid" "${argv[0]}" cockpit-web ;;
    bash | sh) ((n >= 2)) && under_root "$pid" "${argv[1]}" bin/cockpit-web ;;
    node | nodejs)
      for ((i = 1; i < n; i++)); do
        [[ "${argv[i]}" == -* ]] || break
      done
      ((i < n)) && under_root "$pid" "${argv[i]}" app/dist-server/index.js
      ;;
    *) return 1 ;;
  esac
}

gone() {
  local st
  kill -0 "$1" 2>/dev/null || return 0
  st="$(ps -o stat= -p "$1" 2>/dev/null)" || return 0
  st=${st//[[:space:]]/}
  [[ -z "$st" || "$st" == Z* ]]
}

# scan_port: fills ours[] (pids), foreign[] ("pid<TAB>cmdline") and unknown[]
# (descriptions of listeners whose owner cannot be read).
ours=() foreign=() unknown=()
scan_port() {
  local pids=() pid f hex inode uid st loc found out err rc line seen=" "
  ours=() foreign=() unknown=()
  if [[ -r /proc/net/tcp ]]; then
    printf -v hex '%04X' "$PORT"
    for f in /proc/net/tcp /proc/net/tcp6; do
      [[ -r "$f" ]] || continue
      {
        read -r _
        while read -r _ loc _ st _ _ _ uid _ inode _; do
          [[ "$st" == 0A && "${loc##*:}" == "$hex" ]] || continue
          command -v find >/dev/null 2>&1 || {
            unknown+=("socket inode $inode, uid $uid (find not found, cannot map it to a pid)")
            continue
          }
          # Other users' fd dirs are unreadable to a non-root heal; an inode
          # with no readable owner lands in unknown[] and is refused.
          out="$(find /proc/[0-9]*/fd -maxdepth 1 -lname "socket:\[$inode\]" 2>/dev/null)" || :
          found=0
          while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            pid=${line#/proc/}
            pid=${pid%%/*}
            found=1
            [[ "$seen" == *" $pid "* ]] || { pids+=("$pid"); seen+="$pid "; }
          done <<<"$out"
          ((found)) || unknown+=("socket inode $inode, uid $uid (owner not readable)")
        done
      } <"$f"
    done
  else
    if ! command -v lsof >/dev/null 2>&1; then
      if (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
        unknown+=("127.0.0.1:$PORT accepts connections (no /proc/net/tcp and lsof not found to name the owner)")
      fi
      return 0
    fi
    rc=0
    err="$(mktemp)"
    out="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -Fp 2>"$err")" || rc=$?
    if [[ "$rc" -ne 0 && -s "$err" ]]; then
      unknown+=("lsof failed (exit $rc): $(printable "$(head -n 3 "$err")")")
    fi
    rm -f "$err"
    while IFS= read -r line; do
      [[ "$line" == p[0-9]* ]] || continue
      pid=${line#p}
      [[ "$seen" == *" $pid "* ]] || { pids+=("$pid"); seen+="$pid "; }
    done <<<"$out"
    if ((${#pids[@]} == 0)) && (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
      unknown+=("127.0.0.1:$PORT accepts connections but lsof lists no owner")
    fi
  fi
  for pid in ${pids[@]+"${pids[@]}"}; do
    read_argv "$pid"
    if ((${#argv[@]} == 0)); then
      gone "$pid" || unknown+=("pid $pid (command line not readable)")
    elif is_ours "$pid"; then
      ours+=("$pid")
    else
      foreign+=("$pid"$'\t'"$(printable "${argv[*]}")")
    fi
  done
}

# stop_ours PID: TERM, then KILL only if the pid still has a cockpit-web
# command line under the install root (the pid may have been reused).
stop_ours() {
  local pid=$1 cmd i
  read_argv "$pid"
  cmd="$(printable "${argv[*]}")"
  kill -TERM "$pid" 2>/dev/null || { gone "$pid" && return 0; refuse "cannot signal stale cockpit-web pid $pid: $cmd"; return 1; }
  for ((i = 0; i < 50; i++)); do
    gone "$pid" && { echo "heal: stopped stale cockpit-web pid $pid (TERM): $cmd"; return 0; }
    sleep 0.1
  done
  read_argv "$pid"
  is_ours "$pid" || { refuse "pid $pid changed after TERM; not sending KILL"; return 1; }
  kill -KILL "$pid" 2>/dev/null || :
  for ((i = 0; i < 20; i++)); do
    gone "$pid" && { echo "heal: stopped stale cockpit-web pid $pid (KILL after 5s TERM): $cmd"; return 0; }
    sleep 0.1
  done
  refuse "stale cockpit-web pid $pid did not exit: $cmd"
  return 1
}

scan_port
if ((${#ours[@]})); then
  for pid in "${ours[@]}"; do
    stop_ours "$pid" || :
  done
  scan_port
fi
held=0
for pid in ${ours[@]+"${ours[@]}"}; do
  refuse "port $PORT still held by cockpit-web pid $pid"
  held=1
done
for entry in ${foreign[@]+"${foreign[@]}"}; do
  refuse "port $PORT held by pid ${entry%%$'\t'*} (not cockpit-web under $root_real); not stopping it: ${entry#*$'\t'}"
  held=1
done
for entry in ${unknown[@]+"${unknown[@]}"}; do
  refuse "port $PORT held by a process heal cannot identify; not stopping it: $entry"
  held=1
done
((held == 0)) || exit 1

echo "heal: ok root=$COCKPIT_INSTALL_ROOT port=$PORT"
