#!/usr/bin/env bash
# C7 done-line 3 (Linux leg): real round-trip through `cockpit notify --sink ntfy` to a
# throwaway ntfy.sh topic. Never Telegram. Fails (not skips) when the network is up but
# the round-trip fails; skips only with an explicit "no network" reason.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init notify-live-ntfy

if [[ "$(uname -s)" != Linux ]]; then
  echo "notify-live-ntfy: skip (Linux leg only)"
  exit 0
fi
if ! curl --silent --max-time 8 -o /dev/null https://ntfy.sh/v1/health; then
  echo "notify-live-ntfy: skip (no network: https://ntfy.sh unreachable)"
  exit 0
fi

unset COCKPIT_TELEGRAM_BOT_TOKEN COCKPIT_TELEGRAM_CHAT_ID COCKPIT_NTFY_TOKEN COCKPIT_NOTIFY_URL COCKPIT_NOTIFY_DRY_RUN
export COCKPIT_NOTIFY_ENV_FILE="$FIXTURE_TEST_ROOT/none.env"
uuid="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
topic="cockpit-ci-${uuid}"
export COCKPIT_NTFY_TOPIC="$topic" COCKPIT_NTFY_SERVER="https://ntfy.sh"
msg="cockpit live ntfy round-trip ${uuid}"

start_ms=$(date +%s%3N)
out="$(cockpit notify --sink ntfy --title "Cockpit CI" "$msg")" || { echo "notify-live-ntfy: FAIL (publish rc=$?: $out)"; exit 1; }
[[ "$out" == "notify: delivered=ntfy sinks=telegram:skip:not-configured,ntfy:ok,desktop:skip:headless id="* ]] ||
  { echo "notify-live-ntfy: FAIL (bad stdout: $out)"; exit 1; }

found=0
for _ in $(seq 1 45); do
  body="$(curl --silent --max-time 10 "https://ntfy.sh/${topic}/json?poll=1" || true)"
  if printf '%s' "$body" | grep -qF "\"message\":\"${msg}\""; then
    found=1
    break
  fi
  sleep 1
done
elapsed=$(($(date +%s%3N) - start_ms))
if [[ "$found" -ne 1 ]]; then
  echo "notify-live-ntfy: FAIL (message not on topic after ${elapsed}ms)"
  exit 1
fi
printf '%s' "$body" | grep -qF '"title":"Cockpit CI"' || { echo "notify-live-ntfy: FAIL (title header lost)"; exit 1; }
echo "notify-live-ntfy: ok (round-trip ${elapsed}ms)"
