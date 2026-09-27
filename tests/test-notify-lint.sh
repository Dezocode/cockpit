#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

findings=0
run_check() {
  local label=$1
  local out
  out="$(bash -c "$2" 2>/dev/null || true)"
  if [[ -n "$out" ]]; then
    echo "$label:"
    echo "$out"
    findings=$((findings + 1))
  fi
}

run_check duplicate-notify-helpers \
  "rg -n 'api\\.telegram\\.org|notify-send|osascript|ntfy\\.sh|hermes send' -g '!bin/cockpit-notify' -g '!tests/**' -g '!docs/**' -g '!*.md' ."

run_check hardcoded-telegram-tokens \
  "rg -nP '\\b\\d{8,10}:[A-Za-z0-9_-]{35}\\b' ."

run_check secrets-in-app-src \
  "rg -n 'TELEGRAM|NOTIFY_KEY|NTFY_(TOPIC|TOKEN)' app/src"

if command -v pnpm >/dev/null 2>&1 && [[ -f app/package.json ]]; then
  run_check secrets-in-dist \
    "(cd app && pnpm build >/dev/null) && rg -n 'TELEGRAM|api\\.telegram|NTFY_' app/dist"
elif [[ -d app/dist ]]; then
  run_check secrets-in-dist \
    "rg -n 'TELEGRAM|api\\.telegram|NTFY_' app/dist"
fi

run_check curl-token-argv \
  "rg -n 'curl [^\\n]*bot\\$|curl [^\\n]*/bot\\$\\{' bin"

run_check tracked-notify-env \
  "git ls-files | rg '(^|/)notify\\.env$' || true"

run_check local-trust-in-packaging \
  "rg -n 'COCKPIT_LOCAL_TRUST' packaging deploy"

run_check nonportable-bin-notify \
  "rg -n '\\btimeout [0-9]|stat -c|readlink -f|sed -i|/proc/' bin/cockpit-notify"

if ! rg -n 'EnvironmentFile=-/etc/cockpit/notify.env' packaging deploy >/dev/null 2>&1; then
  echo "missing-positive: EnvironmentFile notify.env"
  findings=$((findings + 1))
fi
if ! rg -n 'app\.post\("/api/notify"' app/server/index.ts >/dev/null 2>&1; then
  echo "missing-positive: app.post /api/notify"
  findings=$((findings + 1))
fi

if [[ "$findings" -eq 0 ]]; then
  echo "notify-lint: 0 findings"
else
  echo "notify-lint: $findings finding(s)"
  exit 1
fi
