#!/usr/bin/env bash
# cockpit laya mcp register/unregister: JSON merge for Cursor, marked TOML block
# for Codex, Hermes manual (never a guessed schema), idempotent, reversible,
# malformed files left byte-identical with exit 1.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init laya-mcp
LAYA_TEST_NAME=laya-mcp
# shellcheck source=lib/laya-fixture.sh
source "$repo_root/tests/lib/laya-fixture.sh"
laya_install_cleanup
unset COCKPIT_LAYA XDG_STATE_HOME XDG_CONFIG_HOME XDG_DATA_HOME
laya="$repo_root/bin/cockpit-laya"
cursor_cfg="$HOME/.cursor/mcp.json"
codex_cfg="$HOME/.codex/config.toml"
sha() { "$LAYA_TEST_PY" -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"; }
backups() { find "$HOME/.cursor" "$HOME/.codex" -name '*.cockpit-bak.*' 2>/dev/null | wc -l | tr -d ' '; }

# Not installed: a clear refusal, nothing written.
out="$(bash "$laya" mcp register --client cursor 2>&1)" && laya_fail "not-installed: register succeeded"
[[ "$out" == *'not installed'* && ! -e "$cursor_cfg" ]] || laya_fail "not-installed: $out"

laya_make_venv
mcp_bin="$(laya_venv_root)/bin/laya-mcp-server"
mkdir -p "$HOME/.cursor" "$HOME/.codex"
printf '{"mcpServers": {"other": {"command": "echo", "args": []}}, "theme": "dark"}\n' >"$cursor_cfg"
printf '# user config\nmodel = "test"\n\n[mcp_servers.other]\ncommand = "echo"\n' >"$codex_cfg"
cp "$cursor_cfg" "$FIXTURE_TEST_ROOT/cursor.orig"
cp "$codex_cfg" "$FIXTURE_TEST_ROOT/codex.orig"

# --dry-run changes nothing.
bash "$laya" mcp register --client all --dry-run >"$FIXTURE_TEST_ROOT/dry.out"
cmp -s "$cursor_cfg" "$FIXTURE_TEST_ROOT/cursor.orig" && cmp -s "$codex_cfg" "$FIXTURE_TEST_ROOT/codex.orig" ||
  laya_fail "dry-run changed a file"
[[ "$(backups)" == 0 ]] || laya_fail "dry-run made a backup"

# cursor-json: merge keeps other servers and keys; command is the installed console script.
out="$(bash "$laya" mcp register --client cursor)"
"$LAYA_TEST_PY" - "$cursor_cfg" "$mcp_bin" <<'PY' || laya_fail "cursor-json: merged file"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["theme"] == "dark" and d["mcpServers"]["other"]["command"] == "echo"
assert d["mcpServers"]["laya"] == {"command": sys.argv[2], "args": [], "env": {"LAYA_DEVICE": "cpu"}}, d
PY
[[ "$(backups)" == 1 ]] || laya_fail "cursor-json: expected one backup before the first change"

# codex-toml: marked block round-trips through tomllib, user keys untouched.
bash "$laya" mcp register --client codex >/dev/null
"$LAYA_TEST_PY" - "$codex_cfg" "$mcp_bin" <<'PY' || laya_fail "codex-toml: tomllib round-trip"
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
assert d["model"] == "test" and d["mcp_servers"]["other"]["command"] == "echo"
assert d["mcp_servers"]["laya"] == {"command": sys.argv[2], "args": [], "env": {"LAYA_DEVICE": "cpu"}}, d
PY
grep -q '^# >>> cockpit laya' "$codex_cfg" || laya_fail "codex-toml: block not marked"

# hermes: no upstream writer in laya 0.3.x → manual, nothing written.
out="$(bash "$laya" mcp register --client hermes)" || laya_fail "hermes: exit $?"
[[ "$out" == 'hermes: manual'* && "$out" == *"$mcp_bin"* ]] || laya_fail "hermes: $out"
[[ ! -e "$HOME/.hermes" ]] || laya_fail "hermes: wrote ~/.hermes"

# idempotent: a second register of every client leaves both files byte-identical.
s1="$(sha "$cursor_cfg")"
s2="$(sha "$codex_cfg")"
n="$(backups)"
out="$(bash "$laya" mcp register --client all)"
[[ "$(sha "$cursor_cfg")" == "$s1" && "$(sha "$codex_cfg")" == "$s2" ]] || laya_fail "idempotent: file changed"
[[ "$(backups)" == "$n" && "$out" == *'cursor: unchanged'* && "$out" == *'codex: unchanged'* ]] ||
  laya_fail "idempotent: $out"

# unregister --client all: removes only Cockpit's entries (Codex byte-identical).
bash "$laya" mcp unregister --client all >/dev/null
cmp -s "$codex_cfg" "$FIXTURE_TEST_ROOT/codex.orig" || laya_fail "unregister: codex not restored"
"$LAYA_TEST_PY" -c 'import json, sys; assert json.load(open(sys.argv[1])) == json.load(open(sys.argv[2]))' \
  "$cursor_cfg" "$FIXTURE_TEST_ROOT/cursor.orig" || laya_fail "unregister: cursor not restored"

# parse-restore: malformed files → exit 1 with a message, file byte-identical.
printf '{"mcpServers": {bad json\n' >"$cursor_cfg"
cp "$cursor_cfg" "$FIXTURE_TEST_ROOT/cursor.bad"
rc=0
out="$(bash "$laya" mcp register --client cursor 2>&1)" || rc=$?
[[ "$rc" == 1 && "$out" == *'not valid JSON'* ]] || laya_fail "parse-restore: cursor rc=$rc $out"
cmp -s "$cursor_cfg" "$FIXTURE_TEST_ROOT/cursor.bad" || laya_fail "parse-restore: cursor file changed"
printf 'model = "unterminated\n' >"$codex_cfg"
cp "$codex_cfg" "$FIXTURE_TEST_ROOT/codex.bad"
rc=0
out="$(bash "$laya" mcp register --client codex 2>&1)" || rc=$?
[[ "$rc" == 1 && "$out" == *'not valid TOML'* ]] || laya_fail "parse-restore: codex rc=$rc $out"
cmp -s "$codex_cfg" "$FIXTURE_TEST_ROOT/codex.bad" || laya_fail "parse-restore: codex file changed"
# An unmanaged [mcp_servers.laya] of the user's own is never overwritten.
printf '[mcp_servers.laya]\ncommand = "mine"\n' >"$codex_cfg"
rc=0
out="$(bash "$laya" mcp register --client codex 2>&1)" || rc=$?
[[ "$rc" == 1 && "$(cat "$codex_cfg")" == *'"mine"'* ]] || laya_fail "parse-restore: unmanaged laya table overwritten"

[[ ! -e "$FIXTURE_TEST_ROOT/mcp-server-ran" ]] || laya_fail "laya-mcp-server was executed"
printf 'laya-mcp: ok (cursor-json, codex-toml, hermes, idempotent, unregister, parse-restore)\n'
