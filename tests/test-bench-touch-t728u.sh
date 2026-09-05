#!/usr/bin/env bash
# t728u-next4 touch proof — SGR mouse receipt on nvim PTY; API touch_probe must not count.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-bench-touch-t728u.XXXXXX)"
mirror="$test_root/proctor"
runtime_dir="$test_root/runtime"
fixture_root="$repo_root/tests/fixtures/bench"
db="$mirror/db/runs.sqlite"
layout="$repo_root/stage/nvim/lua/config/cockpit-bench.lua"
bare="$repo_root/stage/nvim-cockpit-bench-bare/init.lua"
nvim_sock="$runtime_dir/nvim.touch.sock"

fail() {
  printf 'Bench touch t728u FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

command -v nvim >/dev/null 2>&1 || command -v "$repo_root/.local/bin/nvim" >/dev/null 2>&1 ||
  fail 'nvim required for touch proof'
command -v python3 >/dev/null 2>&1 || fail 'python3 required for PTY SGR touch proof'

mkdir -p "$mirror/db" "$runtime_dir" "$test_root/home"
install -m 0644 "$fixture_root/MODELS_INDEX.csv" "$mirror/MODELS_INDEX.csv"
install -m 0644 "$fixture_root/CROSSREF_LINKS.csv" "$mirror/CROSSREF_LINKS.csv"

sqlite3 "$db" <<'SQL'
PRAGMA foreign_keys = ON;
CREATE TABLE models (model_id TEXT PRIMARY KEY, agent_class TEXT NOT NULL, home_path TEXT NOT NULL, notes TEXT);
CREATE TABLE runs (run_id TEXT PRIMARY KEY, model_id TEXT NOT NULL REFERENCES models(model_id), role TEXT, campaign TEXT, disposition TEXT, scored_at TEXT, payload_json TEXT NOT NULL);
CREATE TABLE run_links (from_run_id TEXT NOT NULL, to_run_id TEXT NOT NULL, link_kind TEXT NOT NULL, PRIMARY KEY (from_run_id, to_run_id, link_kind));
INSERT INTO models VALUES
  ('gpt-5.6-sol', 'frontier_subscription', 'bench/codex/sol', 'peer fixture'),
  ('local/Qwen3.5-4B', 'local', 'bench/local', 'local fixture');
INSERT INTO runs VALUES
  ('run-sol-001', 'gpt-5.6-sol', 'sol_admin', 'sol-v1.7.1', 'incomplete', '2026-09-04T19:54:34Z', '{}'),
  ('run-local-001', 'local/Qwen3.5-4B', 'experiment_worker', 'sol-v1.7.1', 'repair', '2026-09-04T19:54:35Z', '{}');
SQL

MIRROR="$mirror" RUNTIME="$runtime_dir" HOME_DIR="$test_root/home" LAYOUT="$layout" BARE="$bare" \
  NVIM_SOCK="$nvim_sock" REPO="$repo_root" python3 - <<'PY'
import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import termios
import time

mirror = os.environ["MIRROR"]
runtime = os.environ["RUNTIME"]
home = os.environ["HOME_DIR"]
layout = os.environ["LAYOUT"]
bare = os.environ["BARE"]
sock = os.environ["NVIM_SOCK"]
repo = os.environ["REPO"]

pid, master = pty.fork()
if pid == 0:
    os.environ.update({
        "TERM": "xterm-256color",
        "HOME": home,
        "COCKPIT_PROCTOR_HOME": mirror,
        "COCKPIT_BENCH_DB": f"{mirror}/db/runs.sqlite",
        "COCKPIT_BENCH_ROOT": mirror,
        "COCKPIT_BENCH_ABSENT": "0",
        "COCKPIT_NVIM_BENCH_LAYOUT_INIT": layout,
        "NVIM_APPNAME": "cockpit-bench-bare",
        "PATH": f"{repo}/.local/bin:{repo}/bin:/usr/bin:/bin",
        "XDG_RUNTIME_DIR": runtime,
        "COCKPIT_BENCH_ONCE": "1",
    })
    os.execlp("nvim", "nvim", "--listen", sock, "-u", bare,
              "-c", "lua dofile(vim.env.COCKPIT_NVIM_BENCH_LAYOUT_INIT).setup()",
              "-c", "set mouse=a")

fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 220, 0, 0))

def drain(seconds: float) -> None:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        ready, _, _ = select.select([master], [], [], 0.05)
        if ready:
            try:
                os.read(master, 65536)
            except OSError:
                return

def receipts() -> int:
    if not os.path.exists(sock):
        return 0
    out = subprocess.check_output(
        ["nvim", "--server", sock,
         "--remote-expr", 'luaeval("vim.g.CockpitBenchTouchReceipts or 0")'],
        text=True,
    ).strip()
    return int(out or 0)

for _ in range(80):
    if os.path.exists(sock):
        break
    time.sleep(0.05)
time.sleep(0.25)

def tap(x: int, y: int) -> None:
    os.write(master, f"\x1b[<0;{x};{y}M".encode())
    os.write(master, f"\x1b[<0;{x};{y}m".encode())
    drain(0.2)

# Real SGR click on nvim PTY (same surface family as cockpit-bench).
tap(1, 3)
time.sleep(0.1)
if receipts() < 1:
    raise SystemExit(
        "SGR mouse did not register touch receipts (API remote-send is not touch proof)"
    )

# Negative control: harness touch_probe must not increment receipts (API ≠ touch PASS).
before = receipts()
subprocess.run(
    ["nvim", "--server", sock,
     "--remote-expr", 'luaeval("vim.g.CockpitBench.touch_probe(3, 0)")'],
    check=True,
)
after = receipts()
if after != before:
    raise SystemExit("touch_probe API incremented receipts (API must not fake touch PASS)")

os.kill(pid, signal.SIGTERM)
try:
    os.waitpid(pid, 0)
except ChildProcessError:
    pass
print(f"touch_receipts={after}")
PY

printf '%s\n' 'Bench touch t728u SGR mouse contract: PASS'
