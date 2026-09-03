#!/usr/bin/env bash
# Regression test for the real Termius input path: tmux receives SGR mouse
# packets through cockpit-client, not through a shell-only mock.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-termius-test.XXXXXX)"
test_home="$test_root/home"
install_tmux_root="$test_root/install-tmux"
test_tmux_root="$test_root/test-tmux"
session=cockpit-test
bar_pid=""
mkdir -p "$test_home" "$install_tmux_root" "$test_tmux_root"

export HOME="$test_home"
export XDG_CONFIG_HOME="$test_home/.config"
export TMUX_TMPDIR="$install_tmux_root"
export PATH="$test_home/.local/bin:$repo_root/bin:/usr/local/bin:/usr/bin:/bin"

# This regression test creates its own tmux server. When it is launched from
# a Cockpit pane, an inherited TMUX socket would otherwise make subsequent
# commands (and cleanup) operate on the live parent server instead of the
# test server. That turns a missing test session into `tmux kill-server` on
# the real Cockpit session and leaves Termius showing `[server exited]`.
unset TMUX TMUX_PANE

tmux_test() {
  env -u TMUX -u TMUX_PANE tmux "$@"
}

cleanup() {
  if [[ "$bar_pid" =~ ^[0-9]+$ ]]; then
    kill "$bar_pid" >/dev/null 2>&1 || true
  fi
  tmux_test kill-server >/dev/null 2>&1 || true
  rm -rf "$test_root"
}
trap cleanup EXIT

"$repo_root/install.sh" >/dev/null
install -m 0644 "$repo_root/tests/fixtures/providers.conf" \
  "$HOME/.config/cockpit/providers.conf"

export TMUX_TMPDIR="$test_tmux_root"
tmux_test -f /dev/null new-session -d -s "$session" -n AGENT -x 80 -y 24 \
  'exec sleep 120'
runtime="$(tmux_test display-message -p -t "$session:AGENT" '#{pane_id}')"
tmux_test set-option -p -t "$runtime" @cockpit_role runtime
tmux_test set-option -p -t "$runtime" @cockpit_runtime_id test
tmux_test set-option -t "$session" @cockpit_runtime test
tmux_test set-option -t "$session" @cockpit_profile termius-ios
tmux_test set-option -t "$session" @cockpit_modality touch
tmux_test set-option -t "$session" mouse on
tmux_test source-file "$HOME/.config/tmux/cockpit.conf"

for spec in "FILES:files" "DIFF:diff" "SETUP:setup" "MAP:map" "PRS:prs" "MEMORY:memory"; do
  name=${spec%%:*}
  role=${spec##*:}
  tmux_test new-window -d -t "$session:" -n "$name" 'exec sleep 120'
  pane="$(tmux_test display-message -p -t "$session:$name" '#{pane_id}')"
  tmux_test set-option -p -t "$pane" @cockpit_role "$role"
done
setup="$(tmux_test display-message -p -t "$session:SETUP" '#{pane_id}')"
tmux_test respawn-pane -k -t "$setup" 'exec cat'

tmux_test set-option -t "$session" status on
tmux_test set-option -t "$session" status-position bottom
tmux_test set-option -t "$session" status-left-length 24
tmux_test set-option -t "$session" status-left 'COCKPIT                 '
tmux_test set-option -t "$session" window-status-separator ' '
tmux_test set-option -t "$session" window-status-format '      #W      '
tmux_test set-option -t "$session" window-status-current-format '      #W      '
tmux_test select-window -t "$session:AGENT"
cockpit-ensure-bar "$session" >/dev/null
sleep 0.25
bar="$(tmux_test show-options -v -t "$session" @cockpit_bar_pane)"
bar_pid="$(tmux_test display-message -p -t "$bar" '#{pane_pid}' 2>/dev/null || true)"

[[ "$(tmux_test display-message -p -t "$bar" '#{@cockpit_role}')" == bar ]]
[[ "$(tmux_test display-message -p -t "$bar" '#{pane_height}')" == 2 ]]
bar_text="$(tmux_test capture-pane -p -t "$bar" -S -3)"
grep -Fq '2:FILES' <<<"$bar_text"
[[ "$(cockpit-bar which 5 "$bar" "$session")" == prs ]]
[[ "$(cockpit-bar which 25 "$bar" "$session")" == runtime ]]
[[ "$(cockpit-bar which 35 "$bar" "$session")" == files ]]
[[ "$(cockpit-bar which 45 "$bar" "$session")" == memory ]]
[[ "$(cockpit-bar which 55 "$bar" "$session")" == model ]]
[[ "$(cockpit-bar which 70 "$bar" "$session")" == restart ]]

keys="$(tmux_test list-keys -T root)"
grep -Fq 'MouseDown1Pane' <<<"$keys"
grep -Fq 'select-pane -t =' <<<"$keys"
grep -Fq 'MouseDown1Status' <<<"$keys"
grep -Fq 'select-window -t =' <<<"$keys"

python3 - "$session" <<'PY'
import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import sys
import termios
import time

session = sys.argv[1]
# The parent test shell deliberately unsets these variables, but remove them
# here too so the PTY child can never attach to the live Cockpit socket.
os.environ.pop("TMUX", None)
os.environ.pop("TMUX_PANE", None)
pid, master = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execlp("cockpit-client", "cockpit-client",
              "tmux", "attach-session", "-t", session)

fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))

def drain(seconds: float) -> None:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        ready, _, _ = select.select([master], [], [], 0.05)
        if ready:
            try:
                os.read(master, 65536)
            except OSError:
                return

def window() -> str:
    return subprocess.check_output(
        ["env", "-u", "TMUX", "-u", "TMUX_PANE", "tmux", "display-message",
         "-p", "-t", session, "#{window_name}"],
        text=True,
    ).strip()

def expect(name: str) -> None:
    actual = window()
    if actual != name:
        raise SystemExit(f"expected {name}, got {actual}")
    print(f"{name}: ok", flush=True)

def select_window(name: str) -> None:
    subprocess.run(["env", "-u", "TMUX", "-u", "TMUX_PANE", "tmux",
                    "select-window", "-t", f"{session}:{name}"],
                   check=True)
    time.sleep(0.1)

def tap(x: int, y: int, release: bool = True) -> None:
    packet = f"\x1b[<0;{x};{y}M".encode()
    if release:
        packet += f"\x1b[<0;{x};{y}m".encode()
    os.write(master, packet)
    drain(0.65)

def release(x: int, y: int) -> None:
    os.write(master, f"\x1b[<0;{x};{y}m".encode())
    drain(0.65)

drain(0.8)

# Toolbar zones: PRS, provider, 2:FILES, MEMORY, MODEL, and RESTART.
tap(5, 1)
expect("PRS")
select_window("AGENT")
tap(25, 1)
expect("SETUP")
select_window("AGENT")
tap(35, 1)
expect("FILES")
select_window("AGENT")
tap(45, 1)
expect("MEMORY")
select_window("AGENT")
tap(55, 1)
expect("SETUP")
select_window("AGENT")
tap(70, 1)
expect("AGENT")

# The bottom status row remains canonical and uses the window under the tap.
tap(45, 24)
expect("FILES")
# COCKPIT/status-left is the SETUP entry point.
tap(5, 24)
expect("SETUP")

# Termius' invalid negative-row packet is repaired by the client bridge.
select_window("AGENT")
tap(5, -24)
expect("PRS")

# MouseUp alone is ignored; it cannot fire a second action.
select_window("AGENT")
release(5, 1)
expect("AGENT")

os.kill(pid, signal.SIGTERM)
try:
    os.waitpid(pid, 0)
except ChildProcessError:
    pass
PY

# Apply the adapter after the input-path checks so this display-only assertion
# cannot alter the PTY session before its first tap.
cockpit-adapt resized "$session" 80 24 >/dev/null
[[ "$(tmux_test show-options -v -t "$session" window-status-format)" == *'#I:#W'* ]]
[[ "$(tmux_test show-options -v -t "$session" window-status-current-format)" == *'#I:#W'* ]]

printf '%s\n' 'Termius touch regression: PASS'
