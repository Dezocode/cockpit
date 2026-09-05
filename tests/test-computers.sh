#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-computers-test.XXXXXX)"
trap 'rm -rf -- "$test_root"' EXIT

runtime_path="$repo_root/bin:$HOME/.local/bin:$PATH"
fixture="$repo_root/tests/fixtures/computers-receipt.tsv"
json_fixture="$repo_root/tests/fixtures/deck.json"
json_sol_fixture="$repo_root/tests/fixtures/deck-sol.json"

command -v jq >/dev/null 2>&1 || {
  printf 'jq is required for the managed node receipt test\n' >&2
  exit 1
}
mkdir -p "$test_root/home/intercom/models" "$test_root/home/intercom/computers"
install -m 0644 "$json_fixture" "$test_root/home/intercom/models/deck.json"
install -m 0644 "$fixture" "$test_root/home/intercom/computers/receipt.tsv"

json_path_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" path
)"
grep -Fxq "$test_root/home/intercom/models/deck.json" <<<"$json_path_output"

json_check_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" check
)"
grep -Fxq 'status=ok' <<<"$json_check_output"
grep -Fxq 'device_count=1' <<<"$json_check_output"

json_roster_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" roster
)"
grep -Fxq $'dezodeck\tdeck\tnode\tonline\tlocal/Qwen3.5-4B' <<<"$json_roster_output"
if grep -Fq 'bench-vm' <<<"$json_roster_output"; then
  printf 'JSON receipt produced an invented or legacy roster row\n' >&2
  exit 1
fi

json_models_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" models
)"
grep -Fxq $'dezodeck\tlocal/Qwen3.5-4B' <<<"$json_models_output"

install -m 0644 "$json_sol_fixture" "$test_root/home/intercom/models/deck-sol.json"
dual_path_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" path
)"
grep -Fxq "$test_root/home/intercom/models/deck.json" <<<"$dual_path_output"
grep -Fxq "$test_root/home/intercom/models/deck-sol.json" <<<"$dual_path_output"

dual_check_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" check
)"
grep -Fxq 'status=ok' <<<"$dual_check_output"
grep -Fxq 'device_count=2' <<<"$dual_check_output"

dual_roster_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" roster
)"
grep -Fxq $'dezodeck\tdeck\tnode\tonline\tlocal/Qwen3.5-4B' <<<"$dual_roster_output"
grep -Fxq $'dezodeck\tdeck-sol\tnode\tonline\tlocal/Sol-8B' <<<"$dual_roster_output"

dual_models_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" models
)"
grep -Fxq $'dezodeck\tlocal/Qwen3.5-4B' <<<"$dual_models_output"
grep -Fxq $'dezodeck\tlocal/Sol-8B' <<<"$dual_models_output"

rm -f "$test_root/home/intercom/models/deck-sol.json"
single_check_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" check
)"
grep -Fxq 'device_count=1' <<<"$single_check_output"
if grep -Fq 'deck-sol' <<<"$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" roster
)"; then
  printf 'COMPUTERS invented a deck-sol row without deck-sol.json\n' >&2
  exit 1
fi

install -m 0644 "$json_sol_fixture" "$test_root/home/intercom/models/deck-sol.json"
printf '%s\n' '{"schema":1,"node":"deck-sol"}' >"$test_root/home/intercom/models/deck-sol.json"
partial_log="$test_root/partial-invalid.log"
partial_check_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" check 2>"$partial_log"
)"
grep -Fxq 'status=ok' <<<"$partial_check_output"
grep -Fxq 'device_count=1' <<<"$partial_check_output"
grep -Fq 'deck-sol.json' "$partial_log"
grep -Fq 'invalid or incomplete' "$partial_log"
partial_roster_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" roster
)"
grep -Fxq $'dezodeck\tdeck\tnode\tonline\tlocal/Qwen3.5-4B' <<<"$partial_roster_output"
if grep -Fq 'deck-sol' <<<"$partial_roster_output"; then
  printf 'COMPUTERS rendered an invalid deck-sol receipt row\n' >&2
  exit 1
fi
rm -f "$test_root/home/intercom/models/deck-sol.json"

output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" --once
)"
grep -Fq 'COMPUTERS' <<<"$output"
grep -Fq 'dezodeck' <<<"$output"
grep -Fq 'Read-only device roster' <<<"$output"
if grep -Fq 'probe' <<<"$output"; then
  printf 'COMPUTERS exposed receipt metadata that must stay hidden\n' >&2
  exit 1
fi

models_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" --once --models
)"
grep -Fq 'MODELS' <<<"$models_output"
grep -Fq 'local/Qwen3.5-4B' <<<"$models_output"

invalid_log="$test_root/invalid.log"
printf '%s\n' '{"schema":1,"node":"deck"}' >"$test_root/home/intercom/models/deck.json"
if (
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" check
) >"$invalid_log" 2>&1; then
  printf 'COMPUTERS accepted an incomplete preferred JSON receipt\n' >&2
  exit 1
fi
grep -Fq 'COMPUTERS unavailable' "$invalid_log"
install -m 0644 "$json_fixture" "$test_root/home/intercom/models/deck.json"

rm -f "$test_root/home/intercom/models/deck.json"
tsv_output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" COCKPIT_INTERCOM_HOME="$test_root/home/intercom" \
    PATH="$runtime_path" "$repo_root/bin/cockpit-computers" --once
)"
grep -Fq 'This host' <<<"$tsv_output"

missing_log="$test_root/missing.log"
if (
  cd -- "$test_root"
  HOME="$test_root/empty" env -u COCKPIT_INTERCOM_HOME PATH="$runtime_path" \
    "$repo_root/bin/cockpit-computers" --once
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
