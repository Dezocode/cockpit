#!/usr/bin/env bash
# Memory plugin must fail closed and filter to index/intercom/hooks only.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/cockpit-memory.XXXXXX)"
test_home="$test_root/home"
intercom_home="$test_root/intercom"
mkdir -p "$test_home/.config/cockpit" "$intercom_home/memory"

cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT

export HOME="$test_home"
export COCKPIT_INTERCOM_HOME="$intercom_home"
export PATH="$repo_root/bin:/usr/bin:/bin"

memory="$repo_root/plugins/cockpit-memory/memory"
fixture="$repo_root/tests/fixtures/cockpit.mmd"

missing_output="$("$memory" check 2>&1 || true)"
grep -qi 'missing' <<<"$missing_output"

install -m 0644 "$fixture" "$intercom_home/memory/cockpit.mmd"

path_output="$("$memory" path)"
grep -Fxq "$intercom_home/memory/cockpit.mmd" <<<"$path_output"

check_output="$("$memory" check)"
grep -q '^status=ok$' <<<"$check_output"
grep -q '^subgraphs=index,intercom,hooks$' <<<"$check_output"

show_output="$("$memory" show)"
grep -q 'subgraph index' <<<"$show_output"
grep -q 'subgraph intercom' <<<"$show_output"
grep -q 'subgraph hooks' <<<"$show_output"
grep -qv 'subgraph Foundry' <<<"$show_output"
grep -qv 'subgraph PiSai' <<<"$show_output"
grep -qv 'Must not render' <<<"$show_output"

list_output="$(cockpit-plugin list)"
grep -q '^cockpit\.memory[[:space:]]' <<<"$list_output"

run_output="$(cockpit-plugin run cockpit.memory check)"
grep -q '^status=ok$' <<<"$run_output"

memory_cli_output="$(memory check)"
grep -q '^status=ok$' <<<"$memory_cli_output"

printf '%s\n' 'Memory plugin regression: PASS'
