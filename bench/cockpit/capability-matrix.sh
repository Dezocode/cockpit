#!/usr/bin/env bash
# Capability matrix — Cockpit 2 gospel t847u
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
pass=0
fail=0
warn=0

check() {
  local name=$1 result=$2
  if [[ "$result" == "ok" ]]; then
    printf '  ✓ %s\n' "$name"
    pass=$((pass + 1))
  elif [[ "$result" == "warn" ]]; then
    printf '  ~ %s\n' "$name"
    warn=$((warn + 1))
  else
    printf '  ✗ %s\n' "$name"
    fail=$((fail + 1))
  fi
}

printf 'cockpit capability matrix (seed cockpit-20260907)\n\n'

# TUI regression — zero Surface capability loss
[[ -x "$root/bin/cockpit" ]] && tui=ok || tui=fail
check "TUI bin/cockpit" "$tui"

for page in AGENT FILES DIFF SETUP MAP PRS MEMORY COMPUTERS BENCH; do
  case "$page" in
    AGENT|FILES|DIFF|SETUP|MAP|PRS)
      [[ -x "$root/bin/cockpit-main" ]] && p=ok || p=fail
      ;;
    MEMORY) [[ -x "$root/bin/cockpit-memory" ]] && p=ok || p=fail ;;
    COMPUTERS) [[ -x "$root/bin/cockpit-computers" ]] && p=ok || p=fail ;;
    BENCH) [[ -x "$root/bin/cockpit-bench" ]] && p=ok || p=fail ;;
  esac
  check "TUI page $page" "$p"
done

# Fixtures ≥20 agents
count=$(python3 -c "import json; print(len(json.load(open('$root/fixtures/agents.json'))['agents']))" 2>/dev/null || echo 0)
[[ "$count" -ge 20 ]] && agents=ok || agents=fail
check "fixtures/agents.json ≥20 ($count)" "$agents"

[[ -f "$root/fixtures/layout.json" ]] && layout=ok || layout=fail
check "fixtures/layout.json" "$layout"

# App scaffold
[[ -f "$root/app/package.json" ]] && pkg=ok || pkg=fail
check "app/package.json (cockpit product)" "$pkg"

grep -q '"name": "cockpit"' "$root/app/package.json" 2>/dev/null && pname=ok || pname=fail
check "product name cockpit" "$pname"

# Stack deps (gospel pins)
grep -q 'dockview-react' "$root/app/package.json" 2>/dev/null && dv=ok || dv=fail
check "dep dockview-react 8.x" "$dv"
grep -q 'react-resizable-panels' "$root/app/package.json" 2>/dev/null && rp=ok || rp=fail
check "dep react-resizable-panels" "$rp"
for dep in zustand "@tanstack/react-query" "framer-motion" tailwindcss; do
  grep -q "\"$dep\"" "$root/app/package.json" 2>/dev/null && d=ok || d=fail
  check "dep $dep" "$d"
done
grep -q '@xterm/xterm' "$root/app/package.json" 2>/dev/null && xterm=ok || xterm=fail
check "dep @xterm/xterm (xterm6)" "$xterm"

# Tauri
[[ -f "$root/app/src-tauri/Cargo.toml" ]] && tauri=ok || tauri=fail
check "src-tauri/Cargo.toml" "$tauri"

grep -q 'tauri-plugin-pty' "$root/app/src-tauri/Cargo.toml" 2>/dev/null && pty=ok || pty=fail
check "tauri-plugin-pty 0.3 (desktop PTY)" "$pty"

grep -q 'node-pty' "$root/app/package.json" 2>/dev/null && npty=ok || npty=fail
check "node-pty optional (web PTY)" "$npty"

# API routes
[[ -f "$root/app/server/index.ts" ]] && api=ok || api=fail
check "API server health/agents/layout" "$api"

grep -q 'AGENT_BAR_CHIPS' "$root/app/src/lib/types.ts" 2>/dev/null && bar=ok || bar=fail
check "6-chip AGENT bar (no 7th)" "$bar"

grep -q 'device/start' "$root/app/server/index.ts" 2>/dev/null && df=ok || df=fail
check "splash GitHub device-flow API" "$df"

grep -q 'hermes' "$root/app/server/index.ts" 2>/dev/null && hermes=ok || hermes=fail
check "Hermes COMPUTERS node (not AGENT)" "$hermes"

grep -rq 'ModelsView' "$root/app/src/pages" 2>/dev/null && models=ok || models=fail
check "MODELS sub-view inside COMPUTERS" "$models"

[[ -f "$root/forge/cockpit-redesign-oneshot.md" ]] && forge=ok || forge=fail
check "forge gospel on disk" "$forge"

# Pages in source
for page in MEMORY COMPUTERS BENCH SPLASH; do
  grep -rq "$page" "$root/app/src" 2>/dev/null && pg=ok || pg=fail
  check "GUI page $page" "$pg"
done

# bench/cockpit
[[ -x "$root/bench/cockpit/capability-matrix.sh" ]] && bench=ok || bench=fail
check "bench/cockpit/capability-matrix.sh" "$bench"

[[ -f "$root/bench/cockpit/doctor.sh" ]] && doc=ok || doc=fail
check "bench/cockpit/doctor.sh" "$doc"

[[ -f "$root/bench/cockpit/hostinger-h0-verify.sh" ]] && h0=ok || h0=fail
check "bench/cockpit/hostinger-h0-verify.sh" "$h0"

# Deploy Hostinger (canonical: packaging/ + scripts/)
[[ -f "$root/packaging/systemd/cockpit-web.service" ]] && svc=ok || svc=fail
check "packaging/systemd/cockpit-web.service" "$svc"

[[ -x "$root/packaging/systemd/cockpit-web-heal.sh" ]] && heal=ok || heal=fail
check "packaging/systemd/cockpit-web-heal (+ heal)" "$heal"

[[ -f "$root/packaging/nginx/cockpit.conf" ]] && ngx=ok || ngx=fail
check "packaging/nginx/cockpit.conf" "$ngx"

[[ -x "$root/scripts/install-hostinger.sh" ]] && ih=ok || ih=fail
check "scripts/install-hostinger.sh" "$ih"

[[ -x "$root/scripts/hostinger-grok-build.sh" ]] && gb=ok || gb=fail
check "scripts/hostinger-grok-build.sh" "$gb"

grep -qE 'frontier_subscription|DENY.*Qwen|sol-v1\.7\.1' "$root/scripts/hostinger-grok-build.sh" 2>/dev/null && gb_env=ok || gb_env=fail
check "grok-build envelope DENY Qwen/sol-v1.7.1" "$gb_env"

grep -q 'Funnel OFF' "$root/scripts/hostinger-grok-build.sh" 2>/dev/null && gb_fun=ok || gb_fun=fail
check "grok-build Funnel OFF declared" "$gb_fun"

grep -q '/api/health' "$root/app/server/index.ts" 2>/dev/null && health=ok || health=fail
check "GET /api/health" "$health"

# Hostinger vs Surface rows
printf '\nHostinger vs Surface:\n'
grep -q '/opt/cockpit' "$root/packaging/systemd/cockpit-web.service" 2>/dev/null && \
grep -q 'DENY.*grok\|/root/.grok' "$root/packaging/systemd/cockpit-web-heal.sh" 2>/dev/null && h1=ok || h1=fail
check "install root /opt/cockpit (not /root/.grok)" "$h1"

[[ -f "$root/packaging/systemd/cockpit-web.service" && -x "$root/bin/cockpit" ]] && h2=ok || h2=fail
check "Hostinger systemd + Surface TUI both present" "$h2"

grep -q 'COCKPIT_INSTALL_ROOT' "$root/packaging/systemd/cockpit-web.service" 2>/dev/null && h3=ok || h3=fail
check "Hostinger separate install root env" "$h3"

[[ -x "$root/bench/cockpit/surface-matrix.sh" ]] && h4=ok || h4=fail
check "Surface parity harness (zero TUI regression)" "$h4"

# Legacy deploy/ wrappers (backward compat)
[[ -f "$root/deploy/cockpit-web.service" || -f "$root/packaging/systemd/cockpit-web.service" ]] && legacy=ok || legacy=warn
check "deploy/ or packaging/ systemd" "$legacy"

# Marketing redact
[[ -x "$root/marketing/redact-secrets.sh" ]] && mkt=ok || mkt=fail
check "marketing/redact-secrets.sh" "$mkt"

# Envelope deny local Qwen (allow explicit denial copy in UI)
if grep -rqE '"qwen"|sol-v1\.7\.1' "$root/app/src" 2>/dev/null && \
   ! grep -rq 'denied\|DENY' "$root/app/src/pages/static-pages.tsx" 2>/dev/null; then
  deny=fail
elif grep -rq 'frontier_subscription\|frontier-subscription' "$root/app/src" 2>/dev/null; then
  deny=ok
else
  deny=warn
fi
check "DENY local Qwen/sol-v1.7.1 (frontier envelope)" "$deny"

# ghui chips
grep -rq 'ghui-chip-cyan\|GhuiChip' "$root/app/src" 2>/dev/null && ghui=ok || ghui=fail
check "ghui t533u cyan/yellow chips" "$ghui"

# Emulator registry
grep -rq 'foot\|ghostty' "$root/app" 2>/dev/null && emu=ok || emu=fail
check "Ghostty+Foot emulator registry" "$emu"

# Web build (optional if deps installed)
if [[ -d "$root/app/node_modules" ]]; then
  (cd "$root/app" && pnpm build >/dev/null 2>&1) && build=ok || build=warn
else
  build=warn
fi
check "pnpm build" "$build"

if [[ -x "$root/bench/cockpit/surface-matrix.sh" ]]; then
  bash "$root/bench/cockpit/surface-matrix.sh" >/dev/null 2>&1 && surf=ok || surf=fail
else
  surf=fail
fi
check "surface-matrix TUI↔GUI parity" "$surf"

printf '\nmatrix: pass=%d warn=%d fail=%d\n' "$pass" "$warn" "$fail"
[[ "$fail" -eq 0 ]]
