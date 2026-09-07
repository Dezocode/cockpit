#!/usr/bin/env bash
# t384u screenshot capture — Cockpit 2.2 visual multiview evidence set
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
profile="${COCKPIT_CAPTURE_PROFILE:-local}"
if [[ "$profile" == "hostinger-live" ]]; then
  out="$root/bench/cockpit/screenshots/t384u-hostinger"
else
  out="$root/bench/cockpit/screenshots/t384u"
fi
mkdir -p "$out"

api_port="${COCKPIT_WEB_PORT:-8787}"
ui_port="${COCKPIT_UI_PORT:-1420}"
api_base="http://localhost:$api_port"
ui_base="http://localhost:$ui_port"

cleanup() {
  [[ -n "${web_pid:-}" ]] && kill "$web_pid" 2>/dev/null || true
  [[ -n "${vite_pid:-}" ]] && kill "$vite_pid" 2>/dev/null || true
}
trap cleanup EXIT

start_api() {
  if curl -sf "$api_base/api/health" >/dev/null 2>&1; then return 0; fi
  COCKPIT_HOSTINGER=1 pnpm --dir "$root/app" exec tsx server/index.ts &
  web_pid=$!
  for _ in $(seq 1 30); do
    curl -sf "$api_base/api/health" >/dev/null 2>&1 && return 0
    sleep 0.4
  done
  return 1
}

start_ui() {
  if curl -sf "$ui_base/" >/dev/null 2>&1; then return 0; fi
  pnpm --dir "$root/app" exec vite --port "$ui_port" --strictPort &
  vite_pid=$!
  for _ in $(seq 1 30); do
    curl -sf "$ui_base/" >/dev/null 2>&1 && return 0
    sleep 0.4
  done
  return 1
}

start_api
start_ui

curl -sf "$api_base/api/health" >"$out/hostinger-health.json"
curl -sf "$api_base/api/agents" >"$out/agents.json"
curl -sf "$api_base/api/computers" >"$out/computers.json"
curl -sf "$api_base/api/memory" >"$out/memory.json"
curl -sf "$api_base/api/auth/gh" >"$out/splash-gh-auth.json"

agent_count=$(python3 -c "import json; print(len(json.load(open('$out/agents.json'))['agents']))")
printf 'agents fixture count: %s (profile=%s)\n' "$agent_count" "$profile"

if ! pnpm --dir "$root/app" exec playwright --version >/dev/null 2>&1; then
  pnpm --dir "$root/app" add -D playwright@1.49.1 2>/dev/null || true
fi
pnpm --dir "$root/app" exec playwright install chromium 2>/dev/null || true

shot() {
  local url=$1 file=$2 wait=${3:-2500}
  pnpm --dir "$root/app" exec playwright screenshot "$url" "$file" --wait-for-timeout "$wait" 2>/dev/null || \
    npx --yes playwright screenshot "$url" "$file" --wait-for-timeout "$wait" 2>/dev/null || true
}

# Pre-auth login splash (hold redirect)
shot "$ui_base/splash?screenshot=login" "$out/login-splash.png"
cp -f "$out/login-splash.png" "$out/splash.png" 2>/dev/null || true

# Staging empty — clear layout first via query
shot "$ui_base/splash/staging?reset=1" "$out/staging-empty.png"

# Staging with 3 panels
shot "$ui_base/splash/staging?demo=3panels" "$out/staging-3-panels.png"

# Graph resize + focus rings (graph panel open) — distinct demo badges
shot "$ui_base/splash/staging?demo=graph" "$out/graph-resize.png" 3500

# Fullscreen staging
shot "$ui_base/splash/staging?demo=fullscreen" "$out/fullscreen.png" 3000

# Focus rings on theme switcher
shot "$ui_base/splash/staging?demo=focus" "$out/focus-rings.png" 3000

# ghui-cyan theme proof (≥3 themes gate)
shot "$ui_base/splash/staging?demo=theme-ghui-cyan&reset=1" "$out/theme-ghui-cyan.png" 3500

# Legacy workspace parity (v2.1.4 baseline)
shot "$ui_base/workspace#AGENT" "$out/agents-20plus.png" 6000
shot "$ui_base/workspace#COMPUTERS" "$out/computers.png" 6000
shot "$ui_base/workspace#MEMORY" "$out/memory.png" 6000

python3 - "$out" "$profile" "$agent_count" "$api_base" <<'PY'
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

out = Path(sys.argv[1])
profile = sys.argv[2]
agent_count = int(sys.argv[3])
api_base = sys.argv[4]

files = [
    "hostinger-health.json",
    "login-splash.png",
    "splash.png",
    "staging-empty.png",
    "staging-3-panels.png",
    "graph-resize.png",
    "fullscreen.png",
    "focus-rings.png",
    "theme-ghui-cyan.png",
    "agents-20plus.png",
    "live-term.png",
    "computers.png",
    "memory.png",
    "agents.json",
    "computers.json",
    "memory.json",
    "splash-gh-auth.json",
]

md5 = {}
for name in files:
    path = out / name
    if path.is_file():
        md5[name] = hashlib.md5(path.read_bytes()).hexdigest()

unique_gate = ["focus-rings.png", "fullscreen.png", "graph-resize.png"]
gate_hashes = [md5[f] for f in unique_gate if f in md5]
if len(gate_hashes) != len(unique_gate):
    missing = [f for f in unique_gate if f not in md5]
    raise SystemExit(f"MANIFEST gate missing files: {missing}")
if len(set(gate_hashes)) != len(unique_gate):
    raise SystemExit(
        f"MANIFEST md5 uniqueness gate FAILED for {unique_gate}: {dict(zip(unique_gate, gate_hashes))}"
    )

manifest = {
    "seed": "cockpit-20260907",
    "version": "2.2.0",
    "profile": profile,
    "agent_count": agent_count,
    "files": [f for f in files if (out / f).is_file()],
    "md5": md5,
    "md5_unique_gate": unique_gate,
    "md5_unique_ok": True,
    "health_url": f"{api_base}/api/health",
    "captured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
(out / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"MANIFEST md5_unique_ok: {unique_gate}")
for f in unique_gate:
    print(f"  {f}: {md5[f]}")
if "theme-ghui-cyan.png" in md5:
    print(f"  theme-ghui-cyan.png: {md5['theme-ghui-cyan.png']}")
PY

printf 't384u evidence (%s): %s\n' "$profile" "$out"
ls -la "$out"
