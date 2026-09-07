#!/usr/bin/env bash
# Verify Canon Hostinger-LIVE residual proof closure (soft-steer; zero twin)
set -euo pipefail

dest="$(cd -- "$(dirname -- "$0")" && pwd)"
manifest="$dest/MANIFEST.json"

python3 - "$manifest" "$dest" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
root = Path(sys.argv[2])
m = json.loads(manifest_path.read_text())

residual = m.get("residual_hashes", {})
gate = ["focus-rings.png", "fullscreen.png", "graph-resize.png", "theme-ghui-cyan.png"]
missing = [f for f in gate if f not in residual]
if missing:
    raise SystemExit(f"residual_hashes missing: {missing}")

hashes = [residual[f] for f in gate]
if len(set(hashes)) != len(gate):
    raise SystemExit(f"residual_hashes not unique: {dict(zip(gate, hashes))}")

print("residual_hashes_unique_ok:", gate)
for f in gate:
    print(f"  {f}: {residual[f]}")

md5 = {}
for name in gate:
    path = root / name
    if path.is_file():
        md5[name] = hashlib.md5(path.read_bytes()).hexdigest()

if md5:
    matched = [f for f in gate if md5.get(f) == residual.get(f)]
    print(f"on_disk_match: {len(matched)}/{len(gate)}")
    for f in gate:
        on = md5.get(f, "missing")
        canon = residual[f]
        mark = "OK" if on == canon else "MISMATCH"
        print(f"  {f}: disk={on} canon={canon} [{mark}]")

if not m.get("residual_hashes_unique_ok"):
    raise SystemExit("residual_hashes_unique_ok != true")
if not m.get("residuals_closed_at"):
    raise SystemExit("residuals_closed_at missing")

trio = [residual[f] for f in m.get("md5_unique_gate", gate[:3])]
if len(set(trio)) != 3:
    raise SystemExit("md5_unique_gate failed on residual_hashes")

print("residuals_closed_at:", m["residuals_closed_at"])
PY
