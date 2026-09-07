#!/usr/bin/env bash
# t384u screenshot capture — splash, ≥20 agents, live term, COMPUTERS, MEMORY, Hostinger health
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
out="$root/bench/cockpit/screenshots/t384u"
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

# JSON evidence (always)
curl -sf "$api_base/api/health" >"$out/hostinger-health.json"
curl -sf "$api_base/api/agents" >"$out/agents.json"
curl -sf "$api_base/api/computers" >"$out/computers.json"
curl -sf "$api_base/api/memory" >"$out/memory.json"
curl -sf "$api_base/api/auth/gh" >"$out/splash-gh-auth.json"

agent_count=$(python3 -c "import json; print(len(json.load(open('$out/agents.json'))['agents']))")
printf 'agents fixture count: %s\n' "$agent_count"

# PNG screenshots via Playwright (chromium)
if ! pnpm --dir "$root/app" exec playwright --version >/dev/null 2>&1; then
  pnpm --dir "$root/app" add -D playwright@1.49.1 2>/dev/null || true
fi
pnpm --dir "$root/app" exec playwright install chromium 2>/dev/null || true

shot() {
  local url=$1 file=$2
  pnpm --dir "$root/app" exec playwright screenshot "$url" "$file" --wait-for-timeout 2000 2>/dev/null || \
    npx --yes playwright screenshot "$url" "$file" --wait-for-timeout 2000 2>/dev/null || true
}

shot "$ui_base/" "$out/splash.png"
shot "$ui_base/workspace" "$out/agents-20plus.png"
shot "$ui_base/workspace#AGENT" "$out/live-term.png"
shot "$ui_base/workspace#COMPUTERS" "$out/computers.png"
shot "$ui_base/workspace#MEMORY" "$out/memory.png"

# Manifest for morning CT review
cat >"$out/MANIFEST.json" <<EOF
{
  "seed": "cockpit-20260907",
  "agent_count": $agent_count,
  "files": [
    "hostinger-health.json",
    "splash.png",
    "agents-20plus.png",
    "live-term.png",
    "computers.png",
    "memory.png",
    "agents.json",
    "computers.json",
    "memory.json",
    "splash-gh-auth.json"
  ],
  "health_url": "$api_base/api/health",
  "captured_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

printf 't384u evidence: %s\n' "$out"
ls -la "$out"
