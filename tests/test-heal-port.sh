#!/usr/bin/env bash
# packaging/systemd/cockpit-web-heal.sh port contract (t1127u C9). Every
# listener below is a process this test started, on an ephemeral 127.0.0.1
# port; teardown signals only those pids, also when a check fails.
#   - a stale cockpit-web / node app/dist-server/index.js under the install root
#     is stopped (TERM, then KILL after the grace); the test's own unrelated
#     listener on the same port is not, and heal exits 1 naming its pid
#   - foreign look-alikes (root-prefix, "..", relative to a foreign cwd) are
#     named and never signalled; an unidentifiable holder is refused the same way
#   - heal-probe: kill-by-port / kill-by-name in any spelling bash would execute
#     is a finding; comments, strings, heredoc bodies and case patterns are not
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
heal="$repo_root/packaging/systemd/cockpit-web-heal.sh"
node_bin="${COCKPIT_TEST_NODE:-node}"
node_bin="$(command -v "$node_bin" 2>/dev/null)" || { echo "heal-port: FAIL node not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "heal-port: FAIL python3 not found"; exit 1; }
bash_bin="$(command -v bash)"
[[ "$(uname -s)" == Darwin ]] && PATH="$PATH:/usr/sbin"

tmp="$(mktemp -d)"
tmp="$(cd -P -- "$tmp" && pwd -P)"
started=()
teardown() {
  local pid
  # Only un-reaped children of this shell are listed, so no pid here can have
  # been reused by a process this test did not start.
  for pid in ${started[@]+"${started[@]}"}; do
    kill -KILL "$pid" 2>/dev/null || :
    wait "$pid" 2>/dev/null || :
  done
  rm -rf "$tmp"
}
trap teardown EXIT

pass=0 fail=0
ok() { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n%s\n' "$1" "${2:-}"; fail=$((fail + 1)); }
check() {
  local name=$1
  shift
  if "$@"; then ok "$name"; else bad "$name" "$out"; fi
}

reap() {
  local pid=$1 keep=() p
  kill -KILL "$pid" 2>/dev/null || :
  wait "$pid" 2>/dev/null || :
  for p in ${started[@]+"${started[@]}"}; do
    [[ "$p" == "$pid" ]] || keep+=("$p")
  done
  started=(${keep[@]+"${keep[@]}"})
}

alive() {
  local st
  kill -0 "$1" 2>/dev/null || return 1
  st="$(ps -o stat= -p "$1" 2>/dev/null)" || return 1
  st=${st//[[:space:]]/}
  [[ -n "$st" && "$st" != Z* ]]
}
dead() { ! alive "$1"; }
accepts() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
refuses() { ! accepts "$1"; }
has() { grep -Fq -- "$1" <<<"$out"; }
lacks() { ! grep -Fq -- "$1" <<<"$out"; }
rc_is() { [[ "$rc" -eq "$1" ]]; }

wait_file() {
  local i
  for ((i = 0; i < 150; i++)); do
    [[ -s "$1" ]] && return 0
    sleep 0.1
  done
  echo "heal-port: FAIL timed out waiting for $1" >&2
  return 1
}

free_port() {
  python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

# Listener helper: "serve" accepts forever; "exec" hands the socket to argv[4:]
# on fd 9 with the same pid. SO_REUSEPORT lets two of the test's own listeners
# share one port. The pidfile is written once listen() returned.
cat >"$tmp/holder.py" <<'PY'
import os, socket, sys
mode, port, pidfile = sys.argv[1], int(sys.argv[2]), sys.argv[3]
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
s.bind(("127.0.0.1", port))
s.listen(16)
with open(pidfile + ".tmp", "w") as fh:
    fh.write("%d %d\n" % (os.getpid(), s.getsockname()[1]))
os.rename(pidfile + ".tmp", pidfile)
if mode == "exec":
    os.dup2(s.fileno(), 9)
    os.execv(sys.argv[4], sys.argv[4:])
while True:
    c, _ = s.accept()
    c.close()
PY

# mk_root DIR: a fake install root whose dist-server is a node listener
# (argv: PORT PIDFILE [ignore-term] [extra...]) and whose bin/cockpit-web
# (argv: READYFILE [exec-on-term]) holds the socket it inherits on fd 9 until
# TERM, or on TERM becomes `sleep 300` with the same pid, still holding it.
mk_root() {
  mkdir -p "$1/app/dist-server" "$1/app/dist" "$1/bin"
  echo '<!doctype html>' >"$1/app/dist/index.html"
  cat >"$1/app/dist-server/index.js" <<'JS'
const net = require("net");
const fs = require("fs");
const [port, pidfile, mode] = process.argv.slice(2);
if (mode === "ignore-term") process.on("SIGTERM", () => {});
const srv = net.createServer((c) => c.end());
srv.listen(Number(port), "127.0.0.1", () => fs.writeFileSync(pidfile, String(process.pid)));
JS
  cat >"$1/bin/cockpit-web" <<'SH'
#!/usr/bin/env bash
if [[ "${2:-}" == exec-on-term ]]; then trap 'exec sleep 300' TERM; else trap 'exit 0' TERM; fi
[[ -n "${1:-}" ]] && echo ready >"$1"
while :; do
  sleep 1 9>&- &
  wait "$!"
done
SH
}

spawn() {
  "$@" >>"$tmp/spawn.log" 2>&1 </dev/null &
  last_pid=$!
  started+=("$last_pid")
}

# spawn_node PIDFILE CWD SCRIPT ARGS...: node in CWD; waits until it listens.
spawn_node() {
  local pidfile=$1 cwd=$2
  shift 2
  (cd "$cwd" && exec "$node_bin" "$@") >>"$tmp/spawn.log" 2>&1 </dev/null &
  last_pid=$!
  started+=("$last_pid")
  wait_file "$pidfile"
  [[ "$(cat "$pidfile")" == "$last_pid" ]] || { echo "heal-port: FAIL node pid mismatch" >&2; return 1; }
}

out="" rc=0
run_heal() {
  local root=$1 port=$2
  shift 2
  rc=0
  out="$(env PATH="$(dirname "$node_bin"):$PATH" COCKPIT_INSTALL_ROOT="$root" COCKPIT_WEB_PORT="$port" "$@" \
    "$heal" 2>&1 </dev/null)" || rc=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
}

# --- install-root deny (/root/.grok* and */saul-go*) -----------------------
# heal-deny-install-root fails when those two globs are removed from the heal
# script. The mutant below deletes that arm and the same assertion must fail.
deny_one() {
  local root=$1
  run_heal "$root" 9
  [[ "$rc" -eq 1 ]] && has "heal: DENY install root $root"
}
echo "== heal-deny-install-root"
for root in /root/.grok /root/.grok/agents "$tmp/saul-go" "$tmp/nested/saul-go-work"; do
  check "heal-deny-install-root $root" deny_one "$root"
done
run_heal "$tmp/missing-root" 9
check "missing root is not a deny" eval "rc_is 1 && has \"heal: missing $tmp/missing-root\" && lacks DENY"

python3 - "$heal" "$tmp/mutant-no-deny.sh" <<'PY'
import sys
src = open(sys.argv[1], encoding="utf-8").read()
kept = []
removed = 0
for line in src.splitlines(True):
    if line.lstrip().startswith("#"):
        kept.append(line)
        continue
    if "/root/.grok*" in line and "*/saul-go*" in line:
        removed += 1
        continue
    kept.append(line)
if removed != 1:
    sys.exit("heal-deny mutant: expected to remove 1 deny arm, removed %d" % removed)
open(sys.argv[2], "w", encoding="utf-8").write("".join(kept))
PY
for root in /root/.grok "$tmp/saul-go"; do
  rc=0
  out="$(env PATH="$(dirname "$node_bin"):$PATH" COCKPIT_INSTALL_ROOT="$root" COCKPIT_WEB_PORT=9 \
    bash "$tmp/mutant-no-deny.sh" 2>&1 </dev/null)" || rc=$?
  if [[ "$rc" -eq 1 ]] && has "heal: DENY install root $root"; then
    bad "mutant-removed-deny still refused $root (heal-deny-install-root would not fail)" "$out"
  else
    ok "mutant-removed-deny: heal-deny-install-root fails for $root (rc=$rc)"
  fi
done

# --- free port -------------------------------------------------------------
root="$tmp/a/root"
mk_root "$root"
port="$(free_port)"
echo "== free port $port"
run_heal "$root" "$port"
check "free port: heal rc=0" rc_is 0
check "free port: heal: ok" has "heal: ok root=$root port=$port"

# --- stale node under the root ----------------------------------------------
root="$tmp/b/root"
mk_root "$root"
port="$(free_port)"
spawn_node "$tmp/b.pid" / "$root/app/dist-server/index.js" "$port" "$tmp/b.pid"
stale=$last_pid
echo "== stale node app/dist-server/index.js under the root (pid $stale, port $port)"
run_heal "$root" "$port"
check "stale node: heal rc=0" rc_is 0
check "stale node: reported stopped (TERM)" has "heal: stopped stale cockpit-web pid $stale (TERM): $node_bin $root/app/dist-server/index.js $port"
check "stale node: pid $stale gone" dead "$stale"
check "stale node: port $port free" refuses "$port"
reap "$stale"

# --- stale cockpit-web + the test's own unrelated listener on the same port ---
root="$tmp/c/root"
mk_root "$root"
spawn python3 "$tmp/holder.py" exec 0 "$tmp/c.stale" "$bash_bin" "$root/bin/cockpit-web" "$tmp/c.ready"
wait_file "$tmp/c.stale"
wait_file "$tmp/c.ready"
read -r stale port <"$tmp/c.stale"
check "cockpit-web stand-in pid is the spawned child" test "$stale" = "$last_pid"
spawn python3 "$tmp/holder.py" serve "$port" "$tmp/c.other"
wait_file "$tmp/c.other"
read -r other _ <"$tmp/c.other"
check "unrelated listener pid is the spawned child" test "$other" = "$last_pid"
echo "== stale bash bin/cockpit-web (pid $stale) + unrelated listener (pid $other), both on port $port"
run_heal "$root" "$port"
check "stale+unrelated: heal rc=1" rc_is 1
check "stale+unrelated: cockpit-web pid $stale stopped" has "heal: stopped stale cockpit-web pid $stale (TERM): $bash_bin $root/bin/cockpit-web"
check "stale+unrelated: output names unrelated pid $other" has "heal: REFUSE port $port held by pid $other (not cockpit-web under $root); not stopping it: "
check "stale+unrelated: cockpit-web pid $stale gone" dead "$stale"
check "stale+unrelated: unrelated pid $other alive" alive "$other"
check "stale+unrelated: unrelated listener still accepts on $port" accepts "$port"
reap "$stale"
reap "$other"

# --- foreign holders: look-alike paths outside the root ------------------------
root="$tmp/d/root"
mk_root "$root"
mk_root "$root-evil"
mk_root "$tmp/d/evil2"
port="$(free_port)"
spawn_node "$tmp/d1.pid" / "$root-evil/app/dist-server/index.js" "$port" "$tmp/d1.pid" serve $'\e[2J'
foreign=$last_pid
echo "== foreign: root-prefix look-alike $root-evil (pid $foreign, port $port)"
run_heal "$root" "$port"
check "prefix look-alike: heal rc=1" rc_is 1
check "prefix look-alike: names pid $foreign and its command line" \
  has "heal: REFUSE port $port held by pid $foreign (not cockpit-web under $root); not stopping it: $node_bin $root-evil/app/dist-server/index.js $port"
check "prefix look-alike: control bytes of a foreign argv are not echoed" lacks $'\e'
check "prefix look-alike: pid $foreign alive" alive "$foreign"
check "prefix look-alike: nothing reported stopped" lacks "stopped stale"
reap "$foreign"

port="$(free_port)"
spawn_node "$tmp/d2.pid" / "$root/../evil2/app/dist-server/index.js" "$port" "$tmp/d2.pid"
foreign=$last_pid
echo "== foreign: $root/../evil2 (pid $foreign, port $port)"
run_heal "$root" "$port"
check "dot-dot look-alike: heal rc=1" rc_is 1
check "dot-dot look-alike: names pid $foreign" has "held by pid $foreign (not cockpit-web under $root)"
check "dot-dot look-alike: pid $foreign alive" alive "$foreign"
reap "$foreign"

port="$(free_port)"
spawn_node "$tmp/d3.pid" "$root-evil" app/dist-server/index.js "$port" "$tmp/d3.pid"
foreign=$last_pid
echo "== foreign: relative app/dist-server/index.js, cwd $root-evil (pid $foreign, port $port)"
run_heal "$root" "$port"
check "relative, foreign cwd: heal rc=1" rc_is 1
check "relative, foreign cwd: names pid $foreign" has "held by pid $foreign (not cockpit-web under $root)"
check "relative, foreign cwd: pid $foreign alive" alive "$foreign"
reap "$foreign"

port="$(free_port)"
spawn_node "$tmp/d4.pid" "$root" app/dist-server/index.js "$port" "$tmp/d4.pid"
stale=$last_pid
echo "== stale: relative app/dist-server/index.js, cwd $root (pid $stale, port $port)"
run_heal "$root" "$port"
check "relative, root cwd: heal rc=0" rc_is 0
check "relative, root cwd: pid $stale stopped" has "heal: stopped stale cockpit-web pid $stale (TERM)"
check "relative, root cwd: pid $stale gone" dead "$stale"
reap "$stale"

# --- pid whose command line changes after TERM: no KILL, named as foreign ------
root="$tmp/g/root"
mk_root "$root"
spawn python3 "$tmp/holder.py" exec 0 "$tmp/g.stale" "$bash_bin" "$root/bin/cockpit-web" "$tmp/g.ready" exec-on-term
wait_file "$tmp/g.stale"
wait_file "$tmp/g.ready"
read -r stale port <"$tmp/g.stale"
echo "== cockpit-web that becomes 'sleep 300' on TERM (pid $stale, port $port)"
run_heal "$root" "$port"
check "argv changed after TERM: heal rc=1" rc_is 1
check "argv changed after TERM: KILL withheld" has "heal: REFUSE pid $stale changed after TERM; not sending KILL"
check "argv changed after TERM: named as a foreign holder" has "held by pid $stale (not cockpit-web under $root); not stopping it: sleep 300"
check "argv changed after TERM: pid $stale alive" alive "$stale"
reap "$stale"

# --- stale holder that ignores TERM --------------------------------------------
root="$tmp/e/root"
mk_root "$root"
port="$(free_port)"
spawn_node "$tmp/e.pid" / "$root/app/dist-server/index.js" "$port" "$tmp/e.pid" ignore-term
stale=$last_pid
echo "== stale node ignoring TERM (pid $stale, port $port)"
run_heal "$root" "$port"
check "TERM-ignoring stale: heal rc=0" rc_is 0
check "TERM-ignoring stale: KILL after the TERM grace" has "heal: stopped stale cockpit-web pid $stale (KILL after 5s TERM)"
check "TERM-ignoring stale: pid $stale gone" dead "$stale"
reap "$stale"

# --- holder lookup unavailable: refuse, signal nothing (even a cockpit pid) ---
if [[ -r /proc/net/tcp ]]; then drop='find'; else drop='lsof'; fi
farm="$tmp/farm"
mkdir -p "$farm"
for cmd in bash env node ps sleep readlink dirname basename mktemp head grep rm cat find lsof; do
  [[ "$cmd" == "$drop" ]] && continue
  p="$(command -v "$cmd" 2>/dev/null)" || continue
  [[ "$p" == /* ]] && ln -sf "$p" "$farm/$cmd"
done
ln -sf "$node_bin" "$farm/node"
root="$tmp/f/root"
mk_root "$root"
port="$(free_port)"
spawn_node "$tmp/f.pid" / "$root/app/dist-server/index.js" "$port" "$tmp/f.pid"
stale=$last_pid
echo "== $drop missing from PATH, cockpit node under the root holds port $port (pid $stale)"
rc=0
out="$(env PATH="$farm" COCKPIT_INSTALL_ROOT="$root" COCKPIT_WEB_PORT="$port" "$heal" 2>&1 </dev/null)" || rc=$?
printf '%s\n' "$out" | sed 's/^/     | /'
check "no $drop: heal rc=1" rc_is 1
check "no $drop: refused as unidentifiable" has "heal: REFUSE port $port held by a process heal cannot identify; not stopping it:"
check "no $drop: pid $stale not signalled" alive "$stale"
reap "$stale"
rc=0
out="$(env PATH="$farm" COCKPIT_INSTALL_ROOT="$root" COCKPIT_WEB_PORT="$port" "$heal" 2>&1 </dev/null)" || rc=$?
printf '%s\n' "$out" | sed 's/^/     | /'
check "no $drop, port free again: heal rc=0" eval 'rc_is 0 && has "heal: ok root=$root port=$port"'

# --- COCKPIT_WEB_PORT is data ----------------------------------------------------
root="$tmp/a/root"
for bad_port in '8787;id' '$(id)' '0' '70000' ' 8787' '1e3'; do
  run_heal "$root" "$bad_port"
  check "COCKPIT_WEB_PORT=$(printf '%q' "$bad_port"): rc=1, invalid" eval 'rc_is 1 && has "heal: invalid COCKPIT_WEB_PORT"'
done

# --- heal-probe ------------------------------------------------------------------
cat >"$tmp/heal_probe.py" <<'PY'
"""heal-probe: must_absent probe for packaging/systemd/cockpit-web-heal.sh.

A finding is a command bash would execute that kills by port or by name:
fuser with a kill flag, the kill-by-name tools, kill of a command-substituted
pid list, xargs kill, eval / sh -c, a printf-joined name, a TOKEN_PART-style name,
or any command name that is only known at run time. Names are compared after
quote removal and expansion of known literals, so quote-, backslash-,
ANSI-C-, printf- and variable-joined spellings match. Comments, strings,
heredoc bodies, [[ ]] operands and case patterns are data.

  heal_probe.py FILE                     exit 0 clean, 1 findings, 2 unreadable / unparseable
  heal_probe.py --write-samples HEAL DIR mutant-*.sh (each must be a finding) + twins.sh (must be clean)
"""
import os
import re
import sys

# Character classes keep these patterns from matching the kill-by-name lint
# in tests/test-workflow-lint.sh, which scans this file's directory.
KILL_BY_NAME = re.compile(r"^(p[k]ill|kill[a]ll)$")
TOKEN_PART = re.compile(r"TOKEN[_]PART[_]")
FUSER = "fuser"
FUSER_KILL = re.compile(r"^(-[A-Za-z]*k[A-Za-z]*|--kill)$")
JOINED_FMT = re.compile(r"^(%s){2,}$")
NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)(\[[^]]*\])?\+?=")
FD_WORD = re.compile(r"^(\d+|\{[A-Za-z_][A-Za-z0-9_]*\})$")
RESERVED = {"if", "then", "else", "elif", "fi", "do", "done", "while", "until", "!", "{", "}", "time"}
DATA_LEAD = {"for", "select", "function", "in", "esac", "]]"}
DECLS = {"local", "declare", "typeset", "readonly", "export"}
SHELLS = {"bash", "sh", "dash", "zsh", "ksh"}
OPS = ["&>>", ";;&", "<<<", "<<-", "&&", "||", ";;", ";&", "|&", "<<", "<>", ">>", ">&", "<&", "&>", ">|",
       ";", "&", "|", "<", ">", "(", ")", "\n"]
REDIR = {"<<<", "<<-", "<<", "<>", ">>", ">&", "<&", "&>", "&>>", ">|", "<", ">"}


class ParseError(Exception):
    pass


class Word:
    def __init__(self, parts, raw, line, start, end):
        self.parts, self.raw, self.line, self.start, self.end = parts, raw, line, start, end


class Lexer:
    def __init__(self, src, line):
        self.s, self.i, self.line = src, 0, line
        self.toks, self.heredocs, self.want_delim = [], [], None

    def peek(self, k=0):
        j = self.i + k
        return self.s[j] if j < len(self.s) else ""

    def cmd_start(self):
        if not self.toks:
            return True
        kind, val = self.toks[-1][0], self.toks[-1][1]
        if kind == "op":
            return val not in REDIR
        return val.raw in RESERVED or val.raw == "for"

    def run(self):
        s = self.s
        while self.i < len(s):
            c = s[self.i]
            if c in " \t":
                self.i += 1
            elif c == "#":
                while self.i < len(s) and s[self.i] != "\n":
                    self.i += 1
            elif c == "\\" and self.peek(1) == "\n":
                self.i += 2
                self.line += 1
            elif c == "\n":
                self.toks.append(("op", "\n", self.line, self.i, self.i + 1))
                self.i += 1
                self.line += 1
                if self.heredocs:
                    self.read_heredocs()
            elif c == "(" and self.peek(1) == "(" and self.cmd_start():
                start, line = self.i, self.line
                self.i += 1
                self.balanced("(", ")")
                self.toks.append(("op", "arith", line, start, self.i))
            elif c in "<>" and self.peek(1) == "(":
                start, line = self.i, self.line
                self.i += 2
                inner = self.balanced("(", ")")
                self.toks.append(("word", Word([("cmd", inner, line)], s[start:self.i], line, start, self.i), line, start, self.i))
            else:
                op = next((o for o in OPS if s.startswith(o, self.i)), None)
                if op:
                    self.toks.append(("op", op, self.line, self.i, self.i + len(op)))
                    self.i += len(op)
                    if op in ("<<", "<<-"):
                        self.want_delim = op
                else:
                    w = self.word()
                    self.toks.append(("word", w, w.line, w.start, w.end))
                    if self.want_delim:
                        delim = "".join(p[1] if p[0] == "lit" else "" for p in flat(w.parts))
                        self.heredocs.append((delim, self.want_delim == "<<-"))
                        self.want_delim = None
        if self.heredocs:
            raise ParseError("heredoc without terminator: %r" % self.heredocs[0][0])
        return self.toks

    def read_heredocs(self):
        s = self.s
        for delim, strip in self.heredocs:
            while True:
                if self.i >= len(s):
                    raise ParseError("heredoc without terminator: %r" % delim)
                j = s.find("\n", self.i)
                j = len(s) if j < 0 else j
                body = s[self.i:j]
                self.i = min(j + 1, len(s))
                self.line += 1
                if (body.lstrip("\t") if strip else body) == delim:
                    break
        self.heredocs = []

    def balanced(self, open_c, close_c):
        s, depth, start = self.s, 1, self.i
        while self.i < len(s):
            c = s[self.i]
            if c == "\\":
                self.i += 2
                continue
            if c == "'":
                j = s.find("'", self.i + 1)
                if j < 0:
                    raise ParseError("unterminated '")
                self.line += s.count("\n", self.i, j)
                self.i = j + 1
                continue
            if c == '"':
                self.dquote()
                continue
            if c == "`":
                self.backtick()
                continue
            if c == "\n":
                self.line += 1
            if c == open_c:
                depth += 1
            elif c == close_c:
                depth -= 1
                if depth == 0:
                    self.i += 1
                    return s[start:self.i - 1]
            self.i += 1
        raise ParseError("unbalanced " + open_c)

    def backtick(self):
        s, line = self.s, self.line
        self.i += 1
        buf = []
        while self.i < len(s) and s[self.i] != "`":
            if s[self.i] == "\\" and self.peek(1) in "`$\\":
                buf.append(s[self.i + 1])
                self.i += 2
                continue
            if s[self.i] == "\n":
                self.line += 1
            buf.append(s[self.i])
            self.i += 1
        if self.i >= len(s):
            raise ParseError("unterminated `")
        self.i += 1
        return ("cmd", "".join(buf), line)

    def dquote(self):
        s, parts, buf = self.s, [], []
        self.i += 1
        while self.i < len(s):
            c = s[self.i]
            if c == '"':
                self.i += 1
                if buf:
                    parts.append(("lit", "".join(buf)))
                return parts
            if c == "\\" and self.peek(1) in '$`"\\\n':
                if self.peek(1) == "\n":
                    self.line += 1
                else:
                    buf.append(self.peek(1))
                self.i += 2
                continue
            if c in "$`":
                if buf:
                    parts.append(("lit", "".join(buf)))
                    buf = []
                parts.append(self.dollar(True) if c == "$" else self.backtick())
                continue
            if c == "\n":
                self.line += 1
            buf.append(c)
            self.i += 1
        raise ParseError('unterminated "')

    def ansi_c(self):
        s, out = self.s, []
        self.i += 2
        simple = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "e": "\x1b", "E": "\x1b",
                  "f": "\f", "v": "\v", "\\": "\\", "'": "'", '"': '"', "?": "?"}
        while self.i < len(s) and s[self.i] != "'":
            c = s[self.i]
            if c != "\\":
                out.append(c)
                self.i += 1
                continue
            n = self.peek(1)
            if n in simple:
                out.append(simple[n])
                self.i += 2
            elif n == "x":
                m = re.match(r"[0-9A-Fa-f]{1,2}", s[self.i + 2:])
                out.append(chr(int(m.group(), 16)) if m else "\\x")
                self.i += 2 + (len(m.group()) if m else 0)
            elif n in "01234567":
                m = re.match(r"[0-7]{1,3}", s[self.i + 1:])
                out.append(chr(int(m.group(), 8)))
                self.i += 1 + len(m.group())
            else:
                out.append("\\" + n)
                self.i += 2
        if self.i >= len(s):
            raise ParseError("unterminated $'")
        self.i += 1
        return ("lit", "".join(out))

    def dollar(self, in_dq):
        s, n, line = self.s, self.peek(1), self.line
        if n == "(":
            self.i += 2
            if self.peek() == "(":
                self.balanced("(", ")")
                return ("dyn", "$((...))")
            return ("cmd", self.balanced("(", ")"), line)
        if n == "{":
            self.i += 2
            inner = self.balanced("{", "}")
            return ("var", inner) if NAME.match(inner) else ("dyn", "${" + inner + "}")
        if n == "'" and not in_dq:
            return self.ansi_c()
        if n == '"' and not in_dq:
            self.i += 1
            return ("group", self.dquote())
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", s[self.i + 1:])
        if m:
            self.i += 1 + len(m.group())
            return ("var", m.group())
        if n and (n.isdigit() or n in "@*#?$!-"):
            self.i += 2
            return ("dyn", "$" + n)
        self.i += 1
        return ("lit", "$")

    def word(self):
        s, start, line, parts, buf = self.s, self.i, self.line, [], []

        def flush():
            if buf:
                parts.append(("lit", "".join(buf)))
                del buf[:]

        while self.i < len(s):
            c = s[self.i]
            if c in " \t\n" or (c in ";&|()<>" and not (c == "(" and buf and buf[-1] == "=")):
                break
            if c == "\\":
                if self.peek(1) == "\n":
                    self.i += 2
                    self.line += 1
                    continue
                buf.append(self.peek(1))
                self.i += 2
            elif c == "'":
                j = s.find("'", self.i + 1)
                if j < 0:
                    raise ParseError("unterminated '")
                buf.append(s[self.i + 1:j])
                self.line += s.count("\n", self.i, j)
                self.i = j + 1
            elif c == '"':
                flush()
                parts.append(("group", self.dquote()))
            elif c == "$":
                flush()
                parts.append(self.dollar(False))
            elif c == "`":
                flush()
                parts.append(self.backtick())
            elif c == "(":
                flush()
                self.i += 1
                parts.append(("dyn", "(" + self.balanced("(", ")") + ")"))
            else:
                buf.append(c)
                self.i += 1
        flush()
        return Word(parts, s[start:self.i], line, start, self.i)


def flat(parts):
    for p in parts:
        if p[0] == "group":
            for q in flat(p[1]):
                yield q
        else:
            yield p


def printf_out(fmt, args):
    if fmt is None or any(a is None for a in args):
        return None
    out, args = [], list(args)
    while True:
        i, used = 0, 0
        while i < len(fmt):
            c = fmt[i]
            if c == "\\" and i + 1 < len(fmt):
                out.append({"n": "\n", "t": "\t", "\\": "\\"}.get(fmt[i + 1], "\\" + fmt[i + 1]))
                i += 2
            elif c == "%" and fmt[i + 1:i + 2] == "%":
                out.append("%")
                i += 2
            elif c == "%" and fmt[i + 1:i + 2] == "s":
                out.append(args.pop(0) if args else "")
                used += 1
                i += 2
            elif c == "%":
                return None
            else:
                out.append(c)
                i += 1
        if not args or not used:
            return "".join(out)


class Probe:
    def __init__(self):
        self.env, self.findings, self.commands = {}, [], 0

    def find(self, line, msg, words):
        self.findings.append("L%d: %s: %s" % (line, msg, " ".join(w.raw for w in words)))

    def value(self, w):
        out = []
        for p in flat(w.parts):
            if p[0] == "lit":
                out.append(p[1])
            elif p[0] == "var":
                v = self.env.get(p[1])
                if v is None:
                    return None
                out.append(v)
            elif p[0] == "cmd":
                v = self.subst_value(p[1], p[2])
                if v is None:
                    return None
                out.append(v)
            else:
                return None
        return "".join(out)

    def subst_value(self, src, line):
        cmds = [c for c in split_commands(Lexer(src, line).run())[0] if c]
        if len(cmds) != 1:
            return None
        words = cmds[0]
        vals = [self.value(w) for w in words]
        if vals[0] == "printf" and len(vals) >= 2 and vals[1] != "-v":
            v = printf_out(vals[1], vals[2:])
        elif vals[0] == "echo" and all(v is not None for v in vals[1:]):
            v = " ".join(a for a in vals[1:] if a not in ("-n", "-e", "-E"))
        else:
            return None
        return None if v is None else v.rstrip("\n")

    def scan(self, src, line, depth=0):
        if depth > 8:
            raise ParseError("command substitution nested too deep")
        cmds, data = split_commands(Lexer(src, line).run())
        for w in data:
            self.nested(w, depth)
        for words in cmds:
            for w in words:
                self.nested(w, depth)
            if words:
                self.command(words)

    def nested(self, w, depth):
        for p in flat(w.parts):
            if p[0] == "cmd":
                self.scan(p[1], p[2], depth + 1)
        if TOKEN_PART.search(w.raw):
            self.find(w.line, "TOKEN_PART-style split name", [w])

    def command(self, words):
        i = 0
        while i < len(words) and words[i].raw in RESERVED:
            i += 1
        if i >= len(words) or words[i].raw in DATA_LEAD:
            return
        while i < len(words) and ASSIGN.match(words[i].raw):
            self.assign(words[i])
            i += 1
        if i >= len(words):
            return
        self.commands += 1
        whole = words
        name = self.value(words[i])
        while name is not None:
            base = name.rsplit("/", 1)[-1]
            if base in DECLS:
                for w in words[i + 1:]:
                    if ASSIGN.match(w.raw):
                        self.assign(w)
                return
            if base == "command" and i + 1 < len(words) and words[i + 1].raw in ("-v", "-V"):
                return
            if base in ("exec", "command", "builtin", "nohup", "setsid", "time", "env", "sudo", "doas",
                        "nice", "stdbuf", "timeout", "xargs"):
                i += 1
                while i < len(words) and (words[i].raw.startswith("-") or (base == "env" and ASSIGN.match(words[i].raw))):
                    takes = (base == "exec" and words[i].raw == "-a") or (base == "env" and words[i].raw == "-u") \
                        or (base == "nice" and words[i].raw == "-n") or (base == "xargs" and words[i].raw in ("-I", "-n", "-P", "-d"))
                    i += 2 if takes else 1
                if base == "timeout" and i < len(words):
                    i += 1
                if i >= len(words):
                    return
                nxt = self.value(words[i])
                if base == "xargs" and nxt is not None and nxt.rsplit("/", 1)[-1] == "kill":
                    self.find(words[i].line, "xargs kill (kill of a piped pid list)", whole)
                name = nxt
                continue
            break
        if name is None:
            self.find(words[i].line, "command name assembled at run time", whole)
            return
        base = name.rsplit("/", 1)[-1]
        args = words[i + 1:]
        vals = [self.value(w) for w in args]
        line = words[i].line
        if base == FUSER and any(v is None or FUSER_KILL.match(v) for v in vals):
            self.find(line, "fuser with a kill flag", whole)
        if KILL_BY_NAME.match(base):
            self.find(line, "kill by process name", whole)
        if base == "kill" and any(p[0] == "cmd" for w in args for p in flat(w.parts)):
            self.find(line, "kill of a command-substituted pid list", whole)
        if base == "eval":
            self.find(line, "eval (assembles commands at run time)", whole)
        if base in SHELLS and any(v is None or re.match(r"^-[A-Za-z]*c", v) for v in vals):
            self.find(line, base + " -c (assembles commands at run time)", whole)
        if base == "printf":
            fmt = vals[2] if len(vals) > 2 and vals[0] == "-v" else (vals[0] if vals else None)
            if fmt is not None and JOINED_FMT.match(fmt):
                self.find(line, "printf-joined name", whole)

    def assign(self, w):
        m = ASSIGN.match(w.raw)
        v = self.value(w)
        self.env[m.group(1)] = None if (v is None or m.group(2) or "+=" in w.raw[:m.end()]) else v.split("=", 1)[1]


def split_commands(toks):
    """Simple commands (lists of Words) plus data words that are never commands."""
    cmds, data, cur, k = [], [], [], 0
    case_stack = []

    def at_start():
        return all(w.raw in RESERVED for w in cur)

    while k < len(toks):
        kind, val = toks[k][0], toks[k][1]
        if kind == "op":
            if val in REDIR:
                if cur and cur[-1].end == toks[k][3] and FD_WORD.match(cur[-1].raw):
                    cur.pop()
                if k + 1 < len(toks) and toks[k + 1][0] == "word":
                    data.append(toks[k + 1][1])
                    k += 1
            else:
                cmds.append(cur)
                cur = []
                if val in (";;", ";&", ";;&") and case_stack:
                    case_stack[-1] = "pattern"
            k += 1
            continue
        w = val
        if case_stack and case_stack[-1] == "pattern" and at_start():
            if w.raw == "esac":
                case_stack.pop()
                k += 1
                continue
            while k < len(toks) and not (toks[k][0] == "op" and toks[k][1] == ")"):
                if toks[k][0] == "word":
                    data.append(toks[k][1])
                k += 1
            case_stack[-1] = "body"
            k += 1
            continue
        if at_start() and w.raw == "case":
            k += 1
            while k < len(toks) and not (toks[k][0] == "word" and toks[k][1].raw == "in"):
                if toks[k][0] == "word":
                    data.append(toks[k][1])
                k += 1
            case_stack.append("pattern")
            k += 1
            continue
        if at_start() and w.raw == "esac" and case_stack:
            case_stack.pop()
            k += 1
            continue
        if at_start() and w.raw == "[[":
            k += 1
            while k < len(toks) and not (toks[k][0] == "word" and toks[k][1].raw == "]]"):
                if toks[k][0] == "word":
                    data.append(toks[k][1])
                k += 1
            k += 1
            continue
        cur.append(w)
        k += 1
    cmds.append(cur)
    return cmds, data


def probe_file(path):
    try:
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
    except (OSError, UnicodeDecodeError) as e:
        print("heal-probe: FAIL cannot read %s: %s" % (path, e))
        return 2
    p = Probe()
    try:
        p.scan(src, 1)
    except ParseError as e:
        print("heal-probe: FAIL cannot parse %s: %s" % (path, e))
        return 2
    for f in p.findings:
        print("heal-probe: %s: %s" % (path, f))
    if p.findings:
        print("heal-probe: %d findings in %s" % (len(p.findings), path))
        return 1
    if p.commands == 0:
        print("heal-probe: FAIL no commands found in %s" % path)
        return 2
    print("heal-probe: clean (%s, %d commands)" % (path, p.commands))
    return 0


def unbracket(pattern):
    return re.sub(r"\[(.)\]", r"\1", pattern)


def write_samples(heal, outdir):
    """Probe inputs only: each is a scratch copy of the heal script with one
    spelling planted before its final `echo "heal: ok`; none is executed."""
    with open(heal, encoding="utf-8") as fh:
        src = fh.read()
    anchor = src.rfind('\necho "heal: ok')
    if anchor < 0:
        sys.exit("heal-probe: FAIL anchor `echo \"heal: ok` not found in %s" % heal)
    f, k, tgt = FUSER, "-k", '"${PORT}/tcp"'
    a, b = f[:2], f[2:]
    joined = "'" + "%s" * 2 + "'"
    by_name = [unbracket(alt) for alt in KILL_BY_NAME.pattern[2:-2].split("|")]
    mutants = [
        ("literal", "%s %s %s" % (f, k, tgt)),
        ("base-94b035a", "if command -v %s >/dev/null 2>&1; then\n  %s %s %s 2>/dev/null || true\nfi" % (f, f, k, tgt)),
        ("quote-split", '"%s""%s" %s %s' % (a, b, k, tgt)),
        ("empty-quote-split", "%s''%s %s %s" % (a, b, k, tgt)),
        ("backslash-split", "%s\\%s %s %s" % (f[0], f[1:], k, tgt)),
        ("ansi-c-hex", "$'" + "".join("\\x%02x" % ord(ch) for ch in f) + "' %s %s" % (k, tgt)),
        ("printf-join", "$(printf %s %s %s) %s %s" % (joined, a, b, k, tgt)),
        ("printf-join-backtick", "`printf %s %s %s` %s %s" % (joined, a, b, k, tgt)),
        ("echo-join", '"$(echo %s)%s" %s %s' % (a, b, k, tgt)),
        ("var-join", 'p1=%s\np2=%s\n"$p1$p2" %s %s' % (a, b, k, tgt)),
        ("brace-join", "p1=%s; p2=%s\n${p1}${p2} %s %s" % (a, b, k, tgt)),
        ("local-var-join", 'heal_x() {\n  local p1=%s p2=%s\n  "$p1$p2" %s %s\n}' % (a, b, k, tgt)),
        ("runtime-name", 'read -r tool <<<"%s%s"\n"$tool" %s %s' % (a, b, k, tgt)),
        ("array-name", 'tool=(%s %s)\n"${tool[0]}${tool[1]}" %s %s' % (a, b, k, tgt)),
        ("exec-prefix", "exec %s %s %s" % (f, k, tgt)),
        ("env-prefix", "env LC_ALL=C %s %s %s" % (f, k, tgt)),
        ("command-prefix", "command %s %s %s" % (f, k, tgt)),
        ("in-command-subst", 'reaped="$(%s %s %s 2>&1)"' % (f, k, tgt)),
        ("in-if-condition", "if %s %s %s; then :; fi" % (f, k, tgt)),
        ("after-pipe", "true | %s %s %s" % (f, k, tgt)),
        ("combined-flags", "%s -sk %s" % (f, tgt)),
        ("long-flag", "%s --kill %s" % (f, tgt)),
        ("runtime-flag", 'opt="$1"\n%s "$opt" %s' % (f, tgt)),
        ("eval-join", 'eval "%s""%s %s %s"' % (a, b, k, tgt)),
        ("sh-c", "sh -c '%s %s %s'" % (f, k, tgt)),
        ("wrapper-func", 'run() { "$@"; }\nrun %s %s %s' % (f, k, tgt)),
        ("kill-port-subst", "kill $(ss -ltnpH \"sport = :${PORT}\" | sed -n 's/.*pid=\\([0-9]*\\).*/\\1/p')"),
        ("kill-port-backtick", "kill -9 `ss -ltnpH | sed -n 's/.*pid=\\([0-9]*\\).*/\\1/p'`"),
        ("xargs-kill", "ss -ltnpH | sed -n 's/.*pid=\\([0-9]*\\).*/\\1/p' | xargs kill"),
        ("printf-joined-name", 'tool="$(printf %s %s %s)"' % (joined, a, b)),
        ("token-part", "%sA=%s" % (unbracket(TOKEN_PART.pattern), a)),
    ] + [("by-name-%d" % n, "%s -f cockpit-web" % name) for n, name in enumerate(by_name)]
    twins = "\n".join([
        "# old bug: %s %s %s stopped whoever held the port" % (f, k, tgt),
        'echo "heal: %s %s was removed (C9)" >/dev/null' % (f, k),
        "printf 'heal: %%s\\n' \"never %s %s %s\" >/dev/null" % (f, k, tgt),
        "note='%s %s %s'" % (f, k, tgt),
        "cat <<'EOF' >/dev/null\n%s %s %s\nEOF" % (f, k, tgt),
        'cat <<-EOF >/dev/null\n\t"%s""%s" %s\n\tEOF' % (a, b, k),
        '[[ "${note:-}" == %s* && -n "${note:-}" ]] || :' % f,
        'case "${note:-}" in\n  %s) : ;;\n  "%s %s") : ;;\n  *) : ;;\nesac' % (f, f, k),
        "%s -n tcp 8787 >/dev/null 2>&1 || :" % f,
        'kill -TERM "${pid:-}" 2>/dev/null || :',
        "printf '%s/%s\\n' \"$root_real\" app >/dev/null",
        "printf '%s %s\\n' a b >/dev/null",
        'pids_note="$(printf \'%%s\\n\' "%s %s")"' % (f, k),
    ])
    os.makedirs(outdir, exist_ok=True)
    for name, text in mutants:
        with open(os.path.join(outdir, "mutant-%s.sh" % name), "w", encoding="utf-8") as fh:
            fh.write(src[:anchor] + "\n" + text + src[anchor:])
    with open(os.path.join(outdir, "twins.sh"), "w", encoding="utf-8") as fh:
        fh.write(src[:anchor] + "\n" + twins + src[anchor:])
    print("heal-probe: wrote %d mutants + twins.sh to %s" % (len(mutants), outdir))


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--write-samples":
        write_samples(sys.argv[2], sys.argv[3])
        sys.exit(0)
    if len(sys.argv) != 2:
        sys.exit("usage: heal_probe.py FILE | --write-samples HEAL DIR")
    sys.exit(probe_file(sys.argv[1]))
PY

probe() {
  command -v python3 >/dev/null 2>&1 || { echo "heal-probe: FAIL (python3 not found)"; return 2; }
  python3 "$tmp/heal_probe.py" "$@"
}

echo "== heal-probe on $heal"
rc=0
out="$(probe "$heal" 2>&1)" || rc=$?
printf '%s\n' "$out" | sed 's/^/     | /'
check "heal-probe: shipped heal script is clean" rc_is 0

python3 "$tmp/heal_probe.py" --write-samples "$heal" "$tmp/samples"
rc=0
out="$(probe "$tmp/samples/twins.sh" 2>&1)" || rc=$?
check "heal-probe negative twins (comment, strings, heredocs, [[ ]], case, fuser listing, kill \$pid, printf '%s/%s'): clean" rc_is 0
for m in "$tmp"/samples/mutant-*.sh; do
  n="${m##*/mutant-}"
  n="${n%.sh}"
  rc=0
  out="$(probe "$m" 2>&1)" || rc=$?
  if [[ "$rc" -eq 1 ]] && grep -q '^heal-probe: .*: L[0-9]*: ' <<<"$out"; then
    ok "heal-probe mutant $n: $(grep -m1 -o 'L[0-9]*: [^:]*' <<<"$out")"
  else
    bad "heal-probe mutant $n: rc=$rc (want 1 + a finding)" "$out"
  fi
done

printf 'echo "unterminated\n' >"$tmp/unparseable.sh"
rc=0
out="$(probe "$tmp/unparseable.sh" 2>&1)" || rc=$?
check "heal-probe: unparseable input fails closed (rc 2)" rc_is 2
rc=0
out="$(probe "$tmp/does-not-exist.sh" 2>&1)" || rc=$?
check "heal-probe: missing input fails closed (rc 2)" rc_is 2
mkdir -p "$tmp/nopy"
rc=0
out="$(PATH="$tmp/nopy" probe "$heal" 2>&1)" || rc=$?
check "heal-probe: python3 missing fails closed (rc 2)" eval 'rc_is 2 && has "python3 not found"'

printf 'heal-port tests: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
