#!/usr/bin/env bash
set -euo pipefail

findings=0
report() {
  local out=$1
  [[ -z "$out" ]] && return 0
  echo "$out"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    findings=$((findings + 1))
  done <<<"$out"
}

report "$(rg -n '\binotifywait\b' bin install.sh scripts plugins -g '!tests/test-portability-lint.sh' 2>/dev/null | rg -v '^bin/cockpit-portable-lib:' || true)"
report "$(rg -n 'stat -[cf] ' bin install.sh plugins tests -g '!tests/test-portability-lint.sh' 2>/dev/null | rg -v '^bin/cockpit-portable-lib:' || true)"
report "$(rg -n 'readlink -f|chmod --reference|sed -i|find [^|]*-printf|xargs -r' bin install.sh plugins tests -g '!tests/test-portability-lint.sh' 2>/dev/null || true)"
report "$(rg -n '/proc/' bin install.sh plugins -g '!tests/test-portability-lint.sh' 2>/dev/null | rg -v '^bin/cockpit-portable-lib:' || true)"
report "$(rg -n '\btimeout [0-9]|\bsha256sum\b' bin plugins tests -g '!tests/test-portability-lint.sh' 2>/dev/null | rg -v '^bin/cockpit-portable-lib:' || true)"
report "$(rg -n 'pgrep [^|]*-a\b' bin -g '!tests/test-portability-lint.sh' 2>/dev/null || true)"
report "$(rg -n 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|exec \{' install.sh bin/cockpit-portable-lib -g '!tests/test-portability-lint.sh' 2>/dev/null || true)"
report "$(rg -n 'COCKPIT_SHELL_RC:-\$\{HOME\}/\.bashrc|alias cockpit="cockpit"|^# Cockpit (PATH|cpr plugin)$' install.sh -g '!tests/test-portability-lint.sh' 2>/dev/null || true)"
report "$(rg -n 'useradd|systemctl' install.sh bin -g '!tests/test-portability-lint.sh' 2>/dev/null | rg -v 'cockpit_service_install_systemd' || true)"
report "$(rg -n 'brew install [^#]*(coreutils|gnu-sed|findutils|gawk|gnu-grep|grep-gnu)' .github/workflows README.md -g '!tests/test-portability-lint.sh' 2>/dev/null || true)"

while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  if ! rg -q 'cockpit_require_bash4|source .*cockpit-lib' "$f" 2>/dev/null; then
    echo "unguarded bash4: $f"
    findings=$((findings + 1))
  fi
done < <(rg -l 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|exec \{' bin -g '!tests/test-portability-lint.sh' 2>/dev/null || true)

if [[ "$findings" -gt 0 ]]; then
  printf 'portability-lint: %s findings\n' "$findings"
  exit 1
fi
printf 'portability-lint: 0 findings\n'
