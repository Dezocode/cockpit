#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
command -v rg >/dev/null 2>&1 || { echo "onboarding-lint: rg required" >&2; exit 1; }

findings=0
hit() { echo "$1"; findings=$((findings + 1)); }

# --- must_absent (each must print nothing via hit) ---
test -e bench/cockpit/doctor.sh && hit "legacy doctor still present"
rg -n 'bench/cockpit/doctor\.sh' -g '!docs/architecture/**' -g '!tests/test-onboarding-lint.sh' -g '!bench/cockpit/audit-proposal.md' -g '!**/*.md' . && hit "stale doctor refs" || true
rg -n 'YOUR_USER' README.md && hit "placeholder clone URL" || true
rg -n 'dezohost|size-owning' bin/cockpit-doctor && hit "host jargon in doctor" || true
rg -n -i '(localStorage|sessionStorage|indexedDB|persist\()[^\n]*(api[_-]?key|token|secret|password)' app/src && hit "browser key storage" || true
tracked=$(git ls-files | rg '(^|/)(\.env(\..*)?|keys\.env|keys\.conf)$' | rg -v '^stage/keys/keys\.conf$' || true)
[ -n "$tracked" ] && hit "tracked env/key files: $tracked"
rg -n 'security add-generic-password[^|\n]*-w ' bin && hit "keychain secret on argv" || true
rg -n 'set-environment -g[^\n]*(API_KEY|TOKEN|TOPIC)' bin && hit "keys in tmux global env" || true
rg -n 'sha256sum|shasum' scripts bin | rg -v '^(scripts/get-cockpit\.sh|bin/cockpit-portable-lib|bin/cockpit-lib):' | rg -v 'test-onboarding' && hit "unsanctioned sha256" || true
rg -nP 'sk-[A-Za-z0-9]{20,}|xai-[A-Za-z0-9]{20,}|\d{8,10}:[A-Za-z0-9_-]{35}' -g '!tests/**' -g '!app/tests/**' . && hit "key-shaped strings" || true

test -e pinokio.js -o -e install.js -o -e start.js -o -e update.js && hit "root-level Pinokio scripts"
test -e tests/pinokio-shape.test.mjs && hit "superseded pinokio-shape test"
test -e stage/keys/keys.conf && hit "second key registry"
rg -n "\.(put|delete)\(\s*['\"](/api)?/keys" app/server && hit "bespoke keys REST" || true
rg -n "/api/keys\b" app/src app/server && hit "old /api/keys route" || true
rg -n "/api/doctor\b" app/src app/server && hit "old /api/doctor route" || true
rg -n 'security add-generic-password|security -i\b|security delete-generic-password' bin app scripts pinokio && hit "Keychain writes" || true
rg -n 'secret-tool store|secret-tool clear' bin app scripts && hit "Secret Service writes" || true
rg -n 'find-generic-password[^\n]*\s-w\b' bin app scripts && hit "Keychain value reads" || true
if test -e bin/cockpit-keys && ! rg -q 'node .*app/server/gev/' bin/cockpit-keys; then hit "cockpit-keys not shim"; fi
if test -e bin/cockpit-doctor && ! rg -q 'node .*app/server/gev/doctor\.mjs' bin/cockpit-doctor; then hit "cockpit-doctor not shim"; fi
rg -n "execFile\([^)]*cockpit-keys" app/server && hit "server→CLI shell-out" || true
if [[ -f third_party/gods-eye-view/PORTMAP.tsv ]]; then
  missing=$(awk -F'\t' 'NR>1 && $5!="TRIVIAL" {print $4}' third_party/gods-eye-view/PORTMAP.tsv | xargs -r rg --files-without-match 'Ported from bilawalsidhu/gods-eye-view@b210ab0' || true)
  [ -n "$missing" ] && hit "ported file missing provenance: $missing"
fi
rg -n 'npm ci' scripts/pinokio-*.mjs | rg -v 'Ported from|get-cockpit' && hit "unadapted npm ci" || true
rg -n 'GEV_LAUNCHER|GEV_PROJECT_ROOT|__gev_sharing_disabled__|configureServer|server\.restart\(' pinokio scripts app/server && hit "unadapted GEV hooks" || true
rg -n 'mapStartup|selectMapStartupRoute|OPENSKY_|AISSTREAM_|FIRMS_MAP_KEY|TOMTOM_' app/server/gev pinokio scripts && hit "GEV-specific content" || true
test -e app/shared/gev && hit "core must live in app/server/gev"
rg -n "HOST:\s*'(0\.0\.0\.0|::)'|allowedHosts:\s*true" pinokio app/vite.config.ts && hit "binds beyond loopback" || true
rg -n -e 'fuser\s+-k' -e 'kill\s+\$\(\s*lsof' -e 'p''kill' -e 'kill''all' tests .github -g '!tests/test-onboarding-lint.sh' -g '!tests/test-*-lint.sh' && hit "foreign port kills" || true
rg -n -- '--ck-' app/src app/src/styles && hit "forbidden --ck- tokens" || true
rg -n "printf '%s%s'|TOKEN_PART_" bin scripts packaging pinokio app/server/gev tests -g '!tests/test-*-lint.sh' -g '!tests/test-onboarding-lint.sh' && hit "obfuscated command names" || true
rg -n 'COCKPIT_HOSTINGER=\$\{COCKPIT_HOSTINGER:-1\}|COCKPIT_HOSTINGER:-\$?\{?1\}' bin scripts packaging && hit "HOSTINGER local default=1" || true
rg -n 'bash "\$t"' .github/workflows 2>/dev/null && hit "CI bash \$t without mode assert" || true
rg -n '0\.0\.0\.0|HOST:\s*['\''"]::|allowedHosts:\s*true' pinokio app/vite.config.ts app/server && hit "all-interfaces bind in C6 paths" || true

# --- positive twins ---
rg -q 'get-cockpit\.sh' README.md || hit "missing get-cockpit in README"
rg -q "don't ask me to paste them into this chat" README.md || hit "missing agent prompt wording"
rg -q 'keys\.env' .gitignore || hit "keys.env not gitignored"
rg -q "PINOKIO_SHARE_VAR=__cockpit_sharing_disabled__" pinokio/_ENVIRONMENT || hit "missing sharing sentinel"
rg -q "path: '\.\.'" pinokio/start.js || hit "missing path .."
rg -q 'admitKeySetupRequest' app/server/gev/keySetup.ts || hit "missing admitKeySetupRequest"
rg -q 'pinokio/ENVIRONMENT' .gitignore || hit "pinokio/ENVIRONMENT not gitignored"
rg -q 'Environment=COCKPIT_HOSTINGER=1' packaging/systemd || hit "missing Hostinger unit HOSTINGER=1 (must stay)"
rg -q -- '--cockpit-' app/src/styles/tokens.css || hit "missing --cockpit- tokens twin"

if [[ "$findings" -gt 0 ]]; then
  echo "onboarding-lint: $findings findings" >&2
  exit 1
fi
echo "onboarding-lint: 0 findings"
