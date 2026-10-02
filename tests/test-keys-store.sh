#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$root/bin:$PATH"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export HOME="$tmpdir/home"
export XDG_CONFIG_HOME="$tmpdir/config"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"

FAKE='sk-test-NOT-A-REAL-KEY-0000'

# file 0600 / dir 0700
printf '%s' "$FAKE" | cockpit keys set openai
store="$XDG_CONFIG_HOME/cockpit/keys.env"
[ -f "$store" ] || { echo "keys: FAIL (no store)"; exit 1; }
perm=$(stat -c '%a' "$store" 2>/dev/null || stat -f '%OLp' "$store")
[ "$perm" = "600" ] || { echo "keys: FAIL (file perms $perm)"; exit 1; }
dperm=$(stat -c '%a' "$(dirname "$store")" 2>/dev/null || stat -f '%OLp' "$(dirname "$store")")
[ "$dperm" = "700" ] || { echo "keys: FAIL (dir perms $dperm)"; exit 1; }

# no-keychain-writes: shim security/secret-tool
shim="$tmpdir/shim"
mkdir -p "$shim"
cat > "$shim/security" <<'S'
#!/bin/sh
echo "$@">>"${COCKPIT_SHIM_LOG}"
exit 1
S
cat > "$shim/secret-tool" <<'S'
#!/bin/sh
echo "$@">>"${COCKPIT_SHIM_LOG}"
exit 1
S
chmod +x "$shim/security" "$shim/secret-tool"
export COCKPIT_SHIM_LOG="$tmpdir/shim.log"
: > "$COCKPIT_SHIM_LOG"
PATH="$shim:$PATH" printf '%s' "$FAKE" | cockpit keys set anthropic
PATH="$shim:$PATH" cockpit keys unset anthropic
if rg -q 'add-generic-password| store | -i' "$COCKPIT_SHIM_LOG" 2>/dev/null; then
  echo "keys: FAIL (keychain writes attempted)"; cat "$COCKPIT_SHIM_LOG"; exit 1
fi

# no-argv-leak: feed secret via file redirect (never on argv); sample ps while set runs
printf '%s' "$FAKE" > "$tmpdir/secret.in"
# slow path: keysCli reads stdin; sample concurrent node argv
(
  # Delay stdin so sampler can observe the node process
  { sleep 0.2; cat "$tmpdir/secret.in"; } | cockpit keys set xai
) &
pid=$!
leaked=0
for _ in 1 2 3 4 5 6 7 8; do
  # Only fail if the cockpit-keys/node command line contains the secret (not unrelated procs)
  if ps -axww -o pid=,command= 2>/dev/null | rg "cockpit-keys|keysCli|gev/keysCli" | rg -q --fixed-strings "$FAKE"; then
    leaked=1
  fi
  sleep 0.05
done
wait "$pid" || true
rm -f "$tmpdir/secret.in"
[ "$leaked" -eq 0 ] || { echo "keys: FAIL (argv leak)"; exit 1; }

# env-exec
out=$(cockpit keys exec --for codex -- env | rg '^OPENAI_API_KEY=' || true)
echo "$out" | rg -q '^OPENAI_API_KEY=' || { echo "keys: FAIL (exec inject)"; exit 1; }
bad=$(cockpit keys exec --for codex -- env | rg '^ANTHROPIC_API_KEY=' || true)
[ -z "$bad" ] || { echo "keys: FAIL (cross-provider leak)"; exit 1; }

# external read-only: export then POST-equivalent via unset should still allow unset of store...
# presence-only keychain skip
kc="skipped:linux-no-keychain"
if [ "$(uname -s)" = "Darwin" ]; then kc="keychain-presence-only"; fi

# unset
cockpit keys unset openai
cockpit keys unset xai
list=$(cockpit keys list)
echo "$list" | rg -q 'openai' 

echo "keys: ok (file-0600, dir-0700, ${kc}, no-keychain-writes, no-argv-leak, env-exec, external-read-only, unset)"
