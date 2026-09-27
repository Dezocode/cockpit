#!/usr/bin/env bash
set -euo pipefail
# Fail-closed scanner: a missing rg or any rg error (exit >= 2, e.g. a bad
# pattern or a vanished path) is a finding, never a silent pass.

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
command -v rg >/dev/null 2>&1 || { echo "portability-lint: FAIL (rg not found)"; exit 1; }

findings=0
# scan RG_ARGS... -> matches in $scan_out (no subshell, so errors are counted).
scan_out=""
scan() {
  local rc=0
  scan_out="$(rg "$@" 2>&1)" || rc=$?
  if [[ "$rc" -ge 2 ]]; then
    printf 'rg error (exit %s) for: rg %s\n%s\n' "$rc" "$*" "$scan_out"
    findings=$((findings + 1))
    scan_out=""
  fi
}
drop() { rg -v "$1" || :; }
report() {
  local out=$1
  [[ -z "$out" ]] && return 0
  echo "$out"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    findings=$((findings + 1))
  done <<<"$out"
}

scan -n '\binotifywait\b' bin install.sh scripts plugins -g '!tests/test-portability-lint.sh'; report "$(drop '^bin/cockpit-portable-lib:' <<<"$scan_out")"
scan -n 'stat -[cf] ' bin install.sh plugins tests -g '!tests/test-portability-lint.sh'; report "$(drop '^bin/cockpit-portable-lib:' <<<"$scan_out")"
scan -n 'readlink -f|chmod --reference|sed -i|find [^|]*-printf|xargs -r' bin install.sh plugins tests -g '!tests/test-portability-lint.sh'; report "$scan_out"
scan -n '/proc/' bin install.sh plugins -g '!tests/test-portability-lint.sh'; report "$(drop '^bin/cockpit-portable-lib:' <<<"$scan_out")"
scan -n '\btimeout [0-9]|\bsha256sum\b' bin plugins tests -g '!tests/test-portability-lint.sh'; report "$(drop '^bin/cockpit-portable-lib:' <<<"$scan_out")"
scan -n 'pgrep [^|]*-a\b' bin -g '!tests/test-portability-lint.sh'; report "$scan_out"
scan -n 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|exec \{' install.sh bin/cockpit-portable-lib -g '!tests/test-portability-lint.sh'; report "$scan_out"
scan -n 'COCKPIT_SHELL_RC:-\$\{HOME\}/\.bashrc|alias cockpit="cockpit"|^# Cockpit (PATH|cpr plugin)$' install.sh -g '!tests/test-portability-lint.sh'; report "$scan_out"
scan -n 'useradd|systemctl' install.sh bin -g '!tests/test-portability-lint.sh'; report "$(drop 'cockpit_service_install_systemd' <<<"$scan_out")"
# Gospel list with a word-bounded grep: GNU grep is the `grep` formula; `ripgrep` is not GNU masking.
scan -n 'brew install [^#]*(coreutils|gnu-sed|findutils|gawk|\bgrep\b)' .github/workflows README.md -g '!tests/test-portability-lint.sh'; report "$scan_out"
# Loopback bind (Forge amendment 2026-09-27). The amendment's first pattern
# `nodeServer\.listen\(\s*port\s*,` also matches the fixed listen(port, host, cb);
# its intent (listen without a host argument) is enforced as port followed by `)` or a callback.
scan -n 'nodeServer\.listen\(\s*port\s*(\)|,\s*(\(|function|async))' app/server/index.ts; report "$scan_out"
scan -n "listen\([^\n]*['\"]0\.0\.0\.0['\"]|listen\([^\n]*['\"]::['\"]" app/server/index.ts; report "$scan_out"
scan -n "COCKPIT_WEB_HOST\s*[:=]\s*['\"]0\.0\.0\.0['\"]|COCKPIT_WEB_HOST\s*[:=]\s*['\"]::['\"]" install.sh packaging bin app/server; report "$scan_out"
# `?? default` keeps an empty COCKPIT_WEB_HOST, and listen(port, "") binds all interfaces.
scan -n 'COCKPIT_WEB_HOST\s*\?\?' app/server/index.ts; report "$scan_out"
scan -n 'COCKPIT_WEB_HOST.*"127\.0\.0\.1"' app/server/index.ts
if [[ -z "$scan_out" ]]; then
  echo "missing positive twin: COCKPIT_WEB_HOST loopback default in app/server/index.ts"
  findings=$((findings + 1))
fi

scan -l 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|exec \{' bin -g '!tests/test-portability-lint.sh'
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  if ! rg -q 'cockpit_require_bash4|source .*cockpit-lib' "$f"; then
    echo "unguarded bash4: $f"
    findings=$((findings + 1))
  fi
done <<<"$scan_out"

if [[ "$findings" -gt 0 ]]; then
  printf 'portability-lint: %s findings\n' "$findings"
  exit 1
fi
printf 'portability-lint: 0 findings\n'
