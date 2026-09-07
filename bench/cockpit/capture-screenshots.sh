#!/usr/bin/env bash
# t384u screenshot capture — splash, agents, term, COMPUTERS, MEMORY, health
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
out="$root/bench/cockpit/screenshots/t384u"
mkdir -p "$out"

port="${COCKPIT_WEB_PORT:-8787}"
base="http://localhost:$port"

if ! curl -sf "$base/api/health" >/dev/null 2>&1; then
  echo "Starting cockpit-web on :$port"
  (cd "$root/app" && pnpm dev:web) &
  web_pid=$!
  trap 'kill $web_pid 2>/dev/null || true' EXIT
  for _ in $(seq 1 30); do
    curl -sf "$base/api/health" >/dev/null 2>&1 && break
    sleep 0.5
  done
fi

# Static evidence files when browser automation unavailable
curl -sf "$base/api/health" >"$out/hostinger-health.json"
curl -sf "$base/api/agents" >"$out/agents.json"
curl -sf "$base/api/computers" >"$out/computers.json"
curl -sf "$base/api/memory" >"$out/memory.json"
curl -sf "$base/api/auth/gh" >"$out/splash-gh-auth.json"

# Build HTML previews for manual/browser capture
cat >"$out/splash-preview.html" <<EOF
<!DOCTYPE html><html><head><title>cockpit splash</title></head>
<body style="background:#0b0f14;color:#22d3ee;font-family:monospace;padding:2rem">
<h1>cockpit splash</h1><pre id="auth"></pre>
<script>fetch('/api/auth/gh').then(r=>r.json()).then(d=>document.getElementById('auth').textContent=JSON.stringify(d,null,2))</script>
</body></html>
EOF

if command -v playwright >/dev/null 2>&1 || npx playwright --version >/dev/null 2>&1; then
  (cd "$root/app" && pnpm dev) &
  vite_pid=$!
  sleep 3
  npx playwright screenshot "http://localhost:1420/" "$out/splash.png" 2>/dev/null || true
  npx playwright screenshot "http://localhost:1420/workspace" "$out/workspace-agents.png" 2>/dev/null || true
  kill $vite_pid 2>/dev/null || true
fi

printf 'Screenshots/evidence: %s\n' "$out"
ls -la "$out"
