#!/usr/bin/env bash
# GET /api/health probe for Hostinger deploy verification
set -euo pipefail

base="${1:-http://127.0.0.1:${COCKPIT_WEB_PORT:-8787}}"
url="${base%/}/api/health"

if curl -sf "$url" | python3 -m json.tool; then
  status=$(curl -sf "$url" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))")
  [[ "$status" == green ]] && exit 0
  exit 1
fi
printf 'health probe failed: %s\n' "$url"
exit 1
