#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init notify-live-ntfy

if [[ "$(uname -s)" != Linux ]]; then
  echo "notify-live-ntfy: skip (non-Linux leg)"
  exit 0
fi

if ! curl --silent --max-time 5 -o /dev/null https://ntfy.sh/; then
  echo "notify-live-ntfy: no network (skip)"
  exit 0
fi

topic="cockpit-ci-$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]' || od -An -N8 -tx1 /dev/urandom | tr -d ' ')"
export COCKPIT_NTFY_TOPIC="$topic"
export COCKPIT_NTFY_SERVER="https://ntfy.sh"
unset COCKPIT_TELEGRAM_BOT_TOKEN COCKPIT_TELEGRAM_CHAT_ID

start_ms=$(date +%s%3N)
out="$(cockpit notify --sink ntfy "live ntfy round-trip ${topic}")"
[[ "$out" == notify:* ]] || { echo "notify-live-ntfy: FAIL (bad stdout)"; exit 1; }

poll_url="https://ntfy.sh/${topic}/json?poll=1"
found=0
for _ in $(seq 1 30); do
  body="$(curl --silent --max-time 10 "$poll_url" || true)"
  if printf '%s' "$body" | grep -q 'live ntfy round-trip'; then
    found=1
    break
  fi
  sleep 1
done
end_ms=$(date +%s%3N)
elapsed=$((end_ms - start_ms))

if [[ "$found" -ne 1 ]]; then
  echo "notify-live-ntfy: FAIL (no message on topic)"
  exit 1
fi

echo "notify-live-ntfy: ok (round-trip ${elapsed}ms)"
