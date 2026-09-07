#!/usr/bin/env bash
# Sync Hostinger-LIVE proofs from t384u-hostinger capture output
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../../.." && pwd)"
src="$root/bench/cockpit/screenshots/t384u-hostinger"
dest="$(cd -- "$(dirname -- "$0")" && pwd)"

if [[ ! -d "$src" ]]; then
  printf 'Source missing — run: COCKPIT_CAPTURE_PROFILE=hostinger-live ./bench/cockpit/capture-screenshots.sh\n' >&2
  exit 1
fi

mkdir -p "$dest"
for f in login-splash.png splash.png staging-empty.png staging-3-panels.png graph-resize.png \
  fullscreen.png focus-rings.png theme-ghui-cyan.png hostinger-health.json \
  MANIFEST.json agents.json computers.json memory.json splash-gh-auth.json; do
  [[ -f "$src/$f" ]] && cp -a "$src/$f" "$dest/$f"
done

python3 - "$dest/MANIFEST.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
m = json.loads(p.read_text())
gate = m.get("md5_unique_gate", ["focus-rings.png", "fullscreen.png", "graph-resize.png"])
md5 = m.get("md5", {})
hashes = [md5[f] for f in gate]
if len(set(hashes)) != len(gate):
    raise SystemExit(f"sync gate FAILED: non-unique md5 for {gate}")
print("sync md5_unique_ok:", gate)
for f in gate:
    print(f"  {f}: {md5[f]}")
PY

printf 'Synced Hostinger-LIVE proofs → %s\n' "$dest"
ls -la "$dest"
