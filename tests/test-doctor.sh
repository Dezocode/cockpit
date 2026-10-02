#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$root/bin:$PATH"
doc="$root/bin/cockpit-doctor"

set +e
json=$("$doc" --json 2>/dev/null)
rc=$?
set -e
echo "$json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "os" in d and "arch" in d and "checks" in d and "required_failed" in d; assert isinstance(d["checks"], list); assert all("id" in c and "level" in c and "status" in c for c in d["checks"]); assert all((c.get("fix") or c["status"]!="fail") for c in d["checks"])'
echo "$json" | rg -q 'dezohost' && { echo "doctor: FAIL (host jargon)"; exit 1; } || true

set +e
json2=$(COCKPIT_DOCTOR_HIDE=tmux "$doc" --json 2>/dev/null)
rc2=$?
set -e
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["required_failed"]>=1; assert any(c["id"]=="tmux" and c["status"]=="fail" and c.get("fix") for c in d["checks"])' "$json2"
[ "$rc2" -ne 0 ] || { echo "doctor: FAIL (expected nonzero exit without tmux)"; exit 1; }

echo "doctor: ok (json-schema, exit-codes, fix-hints, no-host-jargon)"
