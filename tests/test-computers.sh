#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-computers-test.XXXXXX)"
trap 'rm -rf -- "$test_root"' EXIT

runtime_path="$repo_root/bin:$HOME/.local/bin:$PATH"
fixture="$repo_root/tests/fixtures/computers-receipt.tsv"

mkdir -p "$test_root/home/intercom/computers"
install -m 0644 "$fixture" "$test_root/home/intercom/computers/receipt.tsv"

output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" --once
)"
grep -Fq 'COMPUTERS' <<<"$output"
grep -Fq 'This host' <<<"$output"
grep -Fq 'Read-only device roster' <<<"$output"

models_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" --once --models
)"
grep -Fq 'MODELS' <<<"$models_output"
grep -Fq 'codex' <<<"$models_output"

missing_log="$test_root/missing.log"
if (
  cd -- "$test_root"
  HOME="$test_root/empty" PATH="$runtime_path" "$repo_root/bin/cockpit-computers" --once
) >"$missing_log" 2>&1; then
  printf 'COMPUTERS did not fail closed for a missing receipt\n' >&2
  exit 1
fi
grep -Fq 'COMPUTERS unavailable' "$missing_log"

grep -Fxq 'id=cockpit.computers' "$repo_root/plugins/cockpit-computers/plugin.conf"
grep -Fxq 'type=cockpit' "$repo_root/plugins/cockpit-computers/plugin.conf"
grep -Fxq 'entrypoint=computers' "$repo_root/plugins/cockpit-computers/plugin.conf"

computers_branch="$(sed -n '/^if \[\[ "\$role" == "computers" \]\]; then/,/^elif \[\[ "\$role" == "memory" \]\]; then/p' \
  "$repo_root/bin/cockpit-touch")"
grep -Fq 'new-window -d -t "$session:" -n COMPUTERS' <<<"$computers_branch"
grep -Fq 'break-pane -d -n COMPUTERS' <<<"$computers_branch"
grep -Fq 'new-window -d -t "$session:" -n COMPUTERS' "$repo_root/bin/cockpit-main"
grep -Fq 'computers:COMPUTERS' "$repo_root/bin/cockpit-adapt"
grep -Fq 'computers:8' "$repo_root/bin/cockpit-adapt"
grep -Fq 'COMPUTERS|computers' "$repo_root/bin/cockpit-wake"
grep -Fq 'ensure_computers' "$repo_root/bin/cockpit-reload-views"
grep -Fq 'memory|computers' "$repo_root/bin/cockpit"

if rg -n 'new-window.*-n MODELS' "$repo_root/bin/cockpit-main" "$repo_root/bin/cockpit-touch" \
  "$repo_root/bin/cockpit-reload-views"; then
  printf 'MODELS must not be a ninth tmux window\n' >&2
  exit 1
fi

for name in AGENT FILES DIFF MAP SETUP PRS MEMORY COMPUTERS; do
  grep -Fq -- "-n $name" "$repo_root/bin/cockpit-main"
done

grep -Fq 'aspects/cockpit-models.md' "$repo_root/plugins/cockpit-computers/README.md"

printf 'computers-local-tests=ok\n'
