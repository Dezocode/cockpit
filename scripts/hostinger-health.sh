#!/usr/bin/env bash
# GET /api/health probe for Hostinger deploy verification (canonical).
set -euo pipefail

wait_secs=0
base="http://127.0.0.1:${COCKPIT_WEB_PORT:-8787}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      wait_secs="${2:-40}"
      shift 2
      ;;
    --wait=*)
      wait_secs="${1#*=}"
      shift
      ;;
    http://*|https://*)
      base="$1"
      shift
      ;;
    *)
      base="$1"
      shift
      ;;
  esac
done

url="${base%/}/api/health"

attempt=1
max_attempts=1
if [[ "$wait_secs" =~ ^[0-9]+$ ]] && ((wait_secs > 0)); then
  max_attempts=$wait_secs
fi

while ((attempt <= max_attempts)); do
  if curl -sf "$url" -o /tmp/cockpit-health-probe.json 2>/dev/null; then
    python3 -m json.tool /tmp/cockpit-health-probe.json
    python3 - <<'PY'
import json, sys
d = json.load(open("/tmp/cockpit-health-probe.json"))
assert d["product"] == "cockpit", d
status = d.get("status", "")
assert status in ("green", "yellow"), d
checks = d.get("checks") or {}
if checks.get("hostinger") is not None:
    assert checks["hostinger"] == "configured", d
sys.exit(0)
PY
    exit 0
  fi
  ((attempt >= max_attempts)) && break
  sleep 0.5
  attempt=$((attempt + 1))
done

printf 'health probe failed: %s\n' "$url"
exit 1
