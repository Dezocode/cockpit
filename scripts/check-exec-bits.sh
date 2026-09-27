#!/usr/bin/env bash
# Committed-tree guard: every shipped script is 100755 in git and executable in
# the checkout, so CI and installs never need to repair modes. Sourced libs are
# the only allowlisted 100644 entries. Run it by path (./scripts/check-exec-bits.sh):
# if its own bit is lost the shell refuses with rc 126 before any check runs.
# Exit: 0 ok, 1 finding, 2 not a git worktree / nothing to check.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" == --root ]]; then
  [[ $# -eq 2 ]] || { echo "usage: ${0##*/} [--root DIR]" >&2; exit 2; }
  root=$2
elif [[ $# -gt 0 ]]; then
  echo "usage: ${0##*/} [--root DIR]" >&2
  exit 2
fi

allowlist=(bin/cockpit-lib bin/cockpit-auth-lib bin/cockpit-agent-lib bin/cockpit-portable-lib bin/cockpit-legacy-names.list)
pathspecs=(
  ':(glob)install.sh'
  ':(glob)scripts/*.sh'
  ':(glob)tests/*.sh'
  ':(glob)packaging/systemd/*.sh'
  ':(glob)bench/cockpit/*.sh'
  ':(glob)marketing/*.sh'
  ':(glob)bin/*'
)

if ! listing="$(git -C "$root" ls-files -s -- "${pathspecs[@]}")"; then
  echo "exec-bits: FAIL git ls-files failed in $root" >&2
  exit 2
fi

checked=0 allowed=0 findings=0 saw_install=0
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  mode="${line%% *}"
  path="${line#*$'\t'}"
  [[ "$path" == install.sh ]] && saw_install=1
  is_allowed=0
  for a in "${allowlist[@]}"; do
    [[ "$path" == "$a" ]] && is_allowed=1
  done
  if ((is_allowed)); then
    allowed=$((allowed + 1))
    continue
  fi
  checked=$((checked + 1))
  if [[ "$mode" != 100755 ]]; then
    printf 'exec-bits: FAIL %s is %s in git (want 100755)\n' "$path" "$mode"
    findings=$((findings + 1))
  elif [[ ! -x "$root/$path" ]]; then
    printf 'exec-bits: FAIL %s is 100755 in git but not executable in the checkout\n' "$path"
    findings=$((findings + 1))
  fi
done <<<"$listing"

if ((checked == 0 || saw_install == 0)); then
  echo "exec-bits: FAIL nothing to check under $root (need install.sh + scripts)" >&2
  exit 2
fi
if ((findings)); then
  printf 'exec-bits: %s findings (%s checked, %s sourced libs allowlisted)\n' "$findings" "$checked" "$allowed"
  exit 1
fi
printf 'exec-bits: ok (%s files 100755; %s sourced libs allowlisted: %s)\n' "$checked" "$allowed" "${allowlist[*]}"
