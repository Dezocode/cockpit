#!/usr/bin/env bash
# Sync ugly baseline proofs from t384u capture output
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../../.." && pwd)"
src="$root/bench/cockpit/screenshots/t384u"
dest="$(cd -- "$(dirname -- "$0")" && pwd)"

if [[ ! -d "$src" ]]; then
  printf 'Source missing — run: ./bench/cockpit/capture-screenshots.sh\n' >&2
  exit 1
fi

mkdir -p "$dest"
for f in login-splash.png splash.png staging-empty.png staging-3-panels.png graph-resize.png \
  fullscreen.png focus-rings.png hostinger-health.json hostinger-fresh-install-health.json \
  MANIFEST.json agents.json computers.json memory.json splash-gh-auth.json; do
  [[ -f "$src/$f" ]] && cp -a "$src/$f" "$dest/$f"
done

printf 'Synced t384u proofs → %s\n' "$dest"
ls -la "$dest"
