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
# Gospel list with a word-bounded grep: GNU grep is the `grep` formula; `ripgrep` is not GNU masking.
report "$(rg -n 'brew install [^#]*(coreutils|gnu-sed|findutils|gawk|\bgrep\b)' .github/workflows README.md -g '!tests/test-portability-lint.sh' 2>/dev/null || true)"
# Loopback bind (Forge amendment 2026-09-27). The amendment's first pattern
# `nodeServer\.listen\(\s*port\s*,` also matches the fixed listen(port, host, cb);
# its intent (listen without a host argument) is enforced as port followed by `)` or a callback.
report "$(rg -n 'nodeServer\.listen\(\s*port\s*(\)|,\s*(\(|function|async))' app/server/index.ts 2>/dev/null || true)"
report "$(rg -n "listen\([^\n]*['\"]0\.0\.0\.0['\"]|listen\([^\n]*['\"]::['\"]" app/server/index.ts 2>/dev/null || true)"
report "$(rg -n "COCKPIT_WEB_HOST\s*[:=]\s*['\"]0\.0\.0\.0['\"]|COCKPIT_WEB_HOST\s*[:=]\s*['\"]::['\"]" install.sh packaging bin app/server 2>/dev/null || true)"
# `?? default` keeps an empty COCKPIT_WEB_HOST, and listen(port, "") binds all interfaces.
report "$(rg -n 'COCKPIT_WEB_HOST\s*\?\?' app/server/index.ts 2>/dev/null || true)"
if ! rg -q 'COCKPIT_WEB_HOST.*"127\.0\.0\.1"' app/server/index.ts 2>/dev/null; then
  echo "missing positive twin: COCKPIT_WEB_HOST loopback default in app/server/index.ts"
  findings=$((findings + 1))
fi

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
