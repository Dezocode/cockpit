#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
real_home="$HOME"
source_file="${COCKPIT_MEMORY_SOURCE:-$real_home/intercom/memory/cockpit.mmd}"
[[ -f "$source_file" ]] || {
  printf 'memory fixture is missing: %s\n' "$source_file" >&2
  exit 1
}

test_root="$(mktemp -d /tmp/cockpit-memory-test.XXXXXX)"
trap 'rm -rf -- "$test_root"' EXIT

runtime_path="$repo_root/bin:$real_home/.local/bin:$PATH"
source_gap=0
for name in index intercom handshake hooks; do
  if ! grep -Eq "^[[:space:]]*subgraph[[:space:]]+${name}([[:space:]]|\\[)" "$source_file"; then
    source_gap=1
    printf 'memory-source-gap=missing-%s\n' "$name" >&2
  fi
done

# The managed source is authoritative. A missing required subgraph must fail
# closed; a complete temporary fixture verifies the actual rendering path.
mkdir -p "$test_root/home/intercom/memory"
install -m 0644 "$source_file" "$test_root/home/intercom/memory/cockpit.mmd"
install -m 0644 "$real_home/intercom/GOAL.md" "$test_root/home/intercom/GOAL.md"
install -m 0644 "$real_home/intercom/HANDSHAKE.md" "$test_root/home/intercom/HANDSHAKE.md"
if ((source_gap)); then
  source_log="$test_root/source.log"
  if (
    cd -- "$repo_root"
    HOME="$real_home" PATH="$runtime_path" "$repo_root/bin/cockpit-memory" --once
  ) >"$source_log" 2>&1; then
    printf 'MEMORY rendered an incomplete managed source\n' >&2
    exit 1
  fi
  grep -Fq 'required subgraph handshake is missing' "$source_log"
fi

if ((source_gap)); then
  printf '%s\n' \
    '  subgraph handshake["3. handshake"]' \
    '    goal["GOAL + HANDSHAKE are coordination inputs"]' \
    '    peers["peers/<id>.md only"]' \
    '    goal --> peers' \
    '  end' >>"$test_root/home/intercom/memory/cockpit.mmd"
fi

output="$(
  cd -- "$repo_root"
  HOME="$test_root/home" PATH="$runtime_path" "$repo_root/bin/cockpit-memory" --once
)"
for expected in MEMORY index intercom handshake hooks "Cockpit PR #1" "folder + GOAL.md" "cockpit.intercom = gh-auth gate"; do
  grep -Fq "$expected" <<<"$output" || {
    printf 'MEMORY render is missing: %s\n' "$expected" >&2
    exit 1
  }
done

mkdir -p "$test_root/project/memory"
install -m 0644 "$test_root/home/intercom/memory/cockpit.mmd" "$test_root/project/memory/cockpit.mmd"
fallback_output="$(
  cd -- "$test_root/project"
  HOME="$test_root/empty" PATH="$runtime_path" "$repo_root/bin/cockpit-memory" --once
)"
grep -Fq 'MEMORY' <<<"$fallback_output"
grep -Fq 'handshake' <<<"$fallback_output"

missing_log="$test_root/missing.log"
if (
  cd -- "$test_root"
  HOME="$test_root/empty" PATH="$runtime_path" "$repo_root/bin/cockpit-memory" --once
) >"$missing_log" 2>&1; then
  printf 'MEMORY did not fail closed for a missing source\n' >&2
  exit 1
fi
grep -Fq 'memory/cockpit.mmd is missing' "$missing_log"

grep -Fxq 'id=cockpit.memory' "$repo_root/plugins/cockpit-memory/plugin.conf"
grep -Fxq 'type=cockpit' "$repo_root/plugins/cockpit-memory/plugin.conf"
grep -Fxq 'entrypoint=memory' "$repo_root/plugins/cockpit-memory/plugin.conf"
plugin_output="$(COCKPIT_CONFIG_HOME="$test_root/config" PATH="$runtime_path" \
  "$repo_root/bin/cockpit-plugin" list)"
grep -Fq $'cockpit.memory\ttype=cockpit' <<<"$plugin_output"
grep -Fq $'cockpit.intercom\ttype=cockpit' <<<"$plugin_output"
plugin_render="$(HOME="$test_root/home" COCKPIT_CONFIG_HOME="$test_root/config" PATH="$runtime_path" \
  "$repo_root/bin/cockpit-plugin" run cockpit.memory --once)"
grep -Fq 'handshake' <<<"$plugin_render"
intercom_ready="$(HOME="$test_root/home" COCKPIT_INTERCOM_ROOT="$test_root/home/intercom" \
  PATH="$runtime_path" "$repo_root/bin/cockpit-intercom" status --summary)"
[[ "$intercom_ready" == ready ]]
intercom_plugin_ready="$(HOME="$test_root/home" COCKPIT_INTERCOM_ROOT="$test_root/home/intercom" \
  COCKPIT_CONFIG_HOME="$test_root/config" PATH="$runtime_path" \
  "$repo_root/bin/cockpit-plugin" run cockpit.intercom sync --summary)"
[[ "$intercom_plugin_ready" == ready ]]
missing_intercom_log="$test_root/intercom-missing.log"
if (HOME="$test_root/home" COCKPIT_INTERCOM_ROOT="$test_root/no-intercom" PATH="$runtime_path" \
  "$repo_root/bin/cockpit-intercom" sync --summary) >"$missing_intercom_log" 2>&1; then
  printf 'intercom sync did not fail closed for a missing projection\n' >&2
  exit 1
fi
grep -Fq 'needs-setup' "$missing_intercom_log"

memory_branch="$(sed -n '/^if \[\[ "\$role" == "memory" \]\]; then/,/^elif \[\[ "\$role" == "setup-legacy" \]\]; then/p' \
  "$repo_root/bin/cockpit-touch")"
if grep -Fq 'display-popup' <<<"$memory_branch"; then
  printf 'MEMORY still uses a popup instead of a named window\n' >&2
  exit 1
fi
grep -Fq 'new-window -d -t "$session:" -n MEMORY' <<<"$memory_branch"
grep -Fq 'new-window -d -t "$session:" -n MEMORY' "$repo_root/bin/cockpit-main"
grep -Fq 'memory:MEMORY' "$repo_root/bin/cockpit-adapt"
grep -Fq 'intercom_source_health' "$repo_root/bin/cockpit-audit"
grep -Fq 'intercom sync' "$repo_root/bin/cockpit-setup"
grep -Fq 'MEMORY' "$repo_root/bin/cockpit-bar"
for name in AGENT FILES DIFF MAP SETUP PRS MEMORY; do
  grep -Fq -- "-n $name" "$repo_root/bin/cockpit-main"
done

if rg -n -i 'F10[^\n]*(memory|MEMORY)|(memory|MEMORY)[^\n]*F10|prefix \+ M' \
  "$repo_root/stage/tmux/cockpit.conf" "$repo_root/bin/cockpit-help"; then
  printf 'F10 or prefix + M still navigates to MEMORY\n' >&2
  exit 1
fi

if rg -n '/workspace/aspects' \
  "$repo_root/bin/cockpit-memory" "$repo_root/plugins/cockpit-memory"; then
  printf 'MEMORY implementation references a forbidden external source\n' >&2
  exit 1
fi

printf 'memory-local-tests=ok\n'
