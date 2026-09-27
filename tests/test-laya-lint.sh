#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

findings=0
scan() {
  local label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'FAIL: %s\n' "$label" >&2
    findings=$((findings + 1))
  fi
}

scan 'runtime_id=codex' rg -n 'runtime_id=codex' bin
scan 'laya hard dep paths' rg -n -i 'laya' app/package.json install.sh scripts/release-bundle.sh
scan 'laya in CI workflows' rg -n 'pip install[^\n]*laya|cockpit laya install' .github/workflows
scan 'non-loopback bind' rg -n '0\.0\.0\.0|LAYA_HOST=\$\{|LAYA_HOST:-' bin/cockpit-laya plugins/cockpit-laya
scan 'gnu-only in laya' rg -n '\btimeout [0-9]|stat -c|readlink -f|sed -i|/proc/' bin/cockpit-laya plugins/cockpit-laya
scan 'raw task in receipts' rg -n '"task"\s*:' bin/cockpit-laya bin/cockpit-lib

positive() {
  local label=$1
  shift
  if ! "$@" >/dev/null 2>&1; then
    printf 'FAIL twin: %s\n' "$label" >&2
    findings=$((findings + 1))
  fi
}

positive 'COCKPIT_LAYA in ci' rg -n 'COCKPIT_LAYA: "0"' .github/workflows/ci.yml
positive 'LAYA_HOST loopback' rg -n 'LAYA_HOST=127\.0\.0\.1' bin/cockpit-laya
positive 'cockpit_route_default' rg -n 'cockpit_route_default\(\)' bin/cockpit-lib

if ((findings > 0)); then
  printf 'laya-lint: %s findings\n' "$findings" >&2
  exit 1
fi
printf 'laya-lint: 0 findings\n'
