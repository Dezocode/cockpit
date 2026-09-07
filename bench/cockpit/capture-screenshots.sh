#!/usr/bin/env bash
# t384u screenshot capture — live React SPA + dist-server API (NOT HTML stand-ins)
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

ensure_build() {
  command -v pnpm >/dev/null 2>&1 || { printf 'pnpm required\n'; exit 1; }
  if [[ ! -f "$root/app/dist/index.html" ]]; then
    printf 'building web dist…\n'
    pnpm --dir "$root/app" build
  fi
  if [[ ! -f "$root/app/dist-server/index.js" ]]; then
    printf 'compiling dist-server…\n'
    pnpm --dir "$root/app" exec tsc -p tsconfig.server.json
  fi
}

start_api() {
  if curl -sf "$api_base/api/health" >/dev/null 2>&1; then
    local src
    src=$(curl -sf "$api_base/api/health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('source',''))" 2>/dev/null || true)
    if [[ "$src" == "app/dist-server/index.js" ]]; then return 0; fi
  fi
  ensure_build
  COCKPIT_INSTALL_ROOT="$root" COCKPIT_HOSTINGER=1 node "$root/app/dist-server/index.js" &
  web_pid=$!
  for _ in $(seq 1 40); do
    if curl -sf "$api_base/api/health" >/dev/null 2>&1; then
      src=$(curl -sf "$api_base/api/health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('source',''))")
      [[ "$src" == "app/dist-server/index.js" ]] && return 0
    fi
    sleep 0.4
  done
  printf 'dist-server failed to start\n'
  return 1
}

start_ui() {
  if curl -sf "$ui_base/" >/dev/null 2>&1; then return 0; fi
  ensure_build
  pnpm --dir "$root/app" exec vite preview --port "$ui_port" --strictPort &
  vite_pid=$!
  for _ in $(seq 1 40); do
    curl -sf "$ui_base/" >/dev/null 2>&1 && return 0
    sleep 0.4
  done
  return 1
}

start_api
start_ui

# JSON evidence (always) — from dist-server, not bootstrap health-server.js
curl -sf "$api_base/api/health" >"$out/hostinger-health.json"
curl -sf "$api_base/api/agents" >"$out/agents.json"
curl -sf "$api_base/api/computers" >"$out/computers.json"
curl -sf "$api_base/api/memory" >"$out/memory.json"
curl -sf "$api_base/api/auth/gh" >"$out/splash-gh-auth.json"

agent_count=$(python3 -c "import json; print(len(json.load(open('$out/agents.json'))['agents']))")
if [[ "$agent_count" -lt 20 ]]; then
  printf 'FAIL: agents fixture count %s < 20\n' "$agent_count"
  exit 1
fi
printf 'agents fixture count: %s\n' "$agent_count"

health_source=$(python3 -c "import json; print(json.load(open('$out/hostinger-health.json')).get('source',''))")
if [[ "$health_source" != "app/dist-server/index.js" ]]; then
  printf 'FAIL: health source %s (expected app/dist-server/index.js)\n' "$health_source"
  exit 1
fi

# PNG screenshots via Playwright (chromium) — live React SPA via vite preview
pnpm --dir "$root/app" exec playwright install chromium 2>/dev/null || true

shot() {
  local url=$1 file=$2 selector=${3:-}
  pnpm --dir "$root/app" exec node scripts/capture-page.mjs "$url" "$file" "$selector"
}

shot "$ui_base/" "$out/splash.png" "text=cockpit"
shot "$ui_base/workspace" "$out/agents-20plus.png" "text=Agents ("
shot "$ui_base/workspace#AGENT" "$out/live-term.png" "text=active:"
shot "$ui_base/workspace#COMPUTERS" "$out/computers.png" "text=COMPUTERS"
shot "$ui_base/workspace#MEMORY" "$out/memory.png" "text=MEMORY"

# Manifest for morning CT review
cat >"$out/MANIFEST.json" <<EOF
{
  "seed": "cockpit-20260907",
  "agent_count": $agent_count,
  "evidence_class": "live_spa_dist_server",
  "ui_source": "vite preview (app/dist)",
  "api_source": "app/dist-server/index.js",
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

printf 't384u evidence (live SPA + dist-server): %s\n' "$out"
ls -la "$out"
