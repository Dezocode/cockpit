#!/usr/bin/env bash
# C7 must_absent block (gospel C7 "must_absent"): every probe must print nothing.
# Fail-closed: a missing rg, a failed web build, or an unscannable app/dist is a finding,
# never a silent pass. This script excludes itself (tests/** is excluded by probe 1).
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v rg >/dev/null 2>&1 || { echo "notify-lint: FAIL (rg not found)"; exit 1; }

findings=0
finding() { printf '%s:\n%s\n' "$1" "$2"; findings=$((findings + 1)); }
# probe LABEL CMD — rg exit 1 (no match) is clean; exit 0 (match) or >=2 (error) is a finding.
probe() {
  local label=$1 out rc=0
  out="$(bash -c "$2" 2>&1)" || rc=$?
  if [[ -n "$out" || "$rc" -ge 2 ]]; then
    finding "$label" "${out:-rg exited $rc}"
  fi
}

probe duplicate-notify-helpers \
  "rg -n 'api\\.telegram\\.org|notify-send|osascript|ntfy\\.sh|hermes send' -g '!bin/cockpit-notify' -g '!tests/**' -g '!docs/**' -g '!*.md' ."
probe hardcoded-telegram-tokens "rg -nP '\\b\\d{8,10}:[A-Za-z0-9_-]{35}\\b' ."
probe secrets-in-app-src "rg -n 'TELEGRAM|NOTIFY_KEY|NTFY_(TOPIC|TOKEN)' app/src"

# Shipped bundle: build it when pnpm is available (gospel form), else scan an existing build.
if command -v pnpm >/dev/null 2>&1 && [[ -f app/package.json ]]; then
  if ! build_log="$(cd app && pnpm build 2>&1)"; then
    finding web-build-failed "$(printf '%s\n' "$build_log" | tail -20)"
  fi
fi
if [[ -f app/dist/index.html ]]; then
  probe secrets-in-dist "rg -n 'TELEGRAM|api\\.telegram|NTFY_' app/dist"
else
  finding secrets-in-dist "app/dist not built (need pnpm or a prebuilt app/dist) — cannot prove the bundle clean"
fi

# 5: single-line curl, same four paths as 5b below (canonical probe 5 scope).
probe curl-token-argv "rg -n 'curl [^\\n]*(bot\\\$|/bot\\\$\\{|Bearer \\\$|-u [^ ]*:\\\$)' bin scripts install.sh app/server"
# 5b: same secrets on a backslash-continued curl (the actual C7 leak shape, 7e0737f bin/cockpit-notify:249-252).
probe5b_cmd=$(cat <<'RG'
rg -U -P -n 'curl(?:[^\n]*\\\n)*?[^\n]*(bot\$|/bot\$\{|Bearer \$|-u [^ ]*:\$)' bin scripts install.sh app/server
RG
)
probe curl-token-argv-multiline "$probe5b_cmd"
probe tracked-notify-env "git ls-files | rg '(^|/)notify\\.env\$'"
probe local-trust-in-packaging "rg -n 'COCKPIT_LOCAL_TRUST' \$(ls -d packaging deploy scripts 2>/dev/null)"
probe nonportable-bin-notify "rg -n '\\btimeout [0-9]|stat -c|readlink[ ]-f|sed[ ]-i|/proc/|\\bsha256sum\\b' bin/cockpit-notify"

# Positive twins (>= 1 line each).
rg -n 'EnvironmentFile=-/etc/cockpit/notify.env' packaging deploy >/dev/null 2>&1 ||
  finding missing-positive "EnvironmentFile=-/etc/cockpit/notify.env in packaging|deploy"
rg -n 'app.post\("/api/notify"' app/server/index.ts >/dev/null 2>&1 ||
  finding missing-positive 'app.post("/api/notify" in app/server/index.ts'

if [[ "$findings" -eq 0 ]]; then
  echo "notify-lint: 0 findings"
else
  echo "notify-lint: $findings finding(s)"
  exit 1
fi
