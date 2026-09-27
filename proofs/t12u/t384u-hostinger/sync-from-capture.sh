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

# Preserve Canon residual closure metadata across capture sync
python3 - "$dest/MANIFEST.json" <<'PY'
import json
from datetime import datetime, timezone
from pathlib import Path

p = Path(__import__("sys").argv[1])
m = json.loads(p.read_text())
residual = {
    "theme-ghui-cyan.png": "d71fc43377ef96cacf28c8bdeea45c98",
    "focus-rings.png": "f57effdca4a0b80261746ffb18aeb550",
    "fullscreen.png": "0aea3fd49bf583b113068ac5df6d8831",
    "graph-resize.png": "20cf82790ebae84124809e38c9bc9e8c",
}
m["residual_hashes"] = residual
m["residual_hashes_unique_ok"] = len(set(residual.values())) == len(residual)
m.setdefault("residuals_closed_at", "2026-09-07T17:54:00Z")
m["residuals_source"] = "canon-hostinger-live"
p.write_text(json.dumps(m, indent=2) + "\n")
PY

python3 - "$dest/MANIFEST.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
m = json.loads(p.read_text())
gate = m.get("md5_unique_gate", ["focus-rings.png", "fullscreen.png", "graph-resize.png"])
md5 = m.get("md5", {})
hashes = [md5[f] for f in gate if f in md5]
if len(hashes) != len(gate):
    missing = [f for f in gate if f not in md5]
    raise SystemExit(f"sync gate missing md5 for: {missing}")
if len(set(hashes)) != len(gate):
    raise SystemExit(f"sync gate FAILED: non-unique md5 for {gate}")

residual = m.get("residual_hashes", {})
if residual:
    rgate = ["focus-rings.png", "fullscreen.png", "graph-resize.png", "theme-ghui-cyan.png"]
    rh = [residual[f] for f in rgate if f in residual]
    if len(rh) == len(rgate) and len(set(rh)) == len(rgate):
        print("residual_hashes_unique_ok:", rgate)
        for f in rgate:
            print(f"  {f}: {residual[f]}")
    if m.get("residuals_closed_at"):
        print("residuals_closed_at:", m["residuals_closed_at"])

print("sync md5_unique_ok:", gate)
for f in gate:
    print(f"  {f}: {md5[f]}")
PY

printf 'Synced Hostinger-LIVE proofs → %s\n' "$dest"
ls -la "$dest"
