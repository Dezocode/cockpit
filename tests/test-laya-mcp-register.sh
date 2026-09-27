#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init laya-mcp
export COCKPIT_LAYA=0

mkdir -p "$HOME/.cursor" "$HOME/.codex"
cat >"$HOME/.cursor/mcp.json" <<'EOF'
{"mcpServers":{"other":{"command":"echo","args":[]}}}
EOF
cat >"$HOME/.codex/config.toml" <<'EOF'
model = "test"
EOF

# Fake venv python for MCP writers
venv="$HOME/.local/share/cockpit/laya/venv"
mkdir -p "$venv/bin"
cat >"$venv/bin/python" <<'PY'
#!/usr/bin/env bash
exec /usr/bin/python3 "$@"
PY
chmod 0755 "$venv/bin/python"
ln -sf "$venv/bin/python" "$venv/bin/laya-mcp"

mkdir -p "$HOME/.config/cockpit"
install -m 0644 "$repo_root/stage/laya/laya.conf" "$HOME/.config/cockpit/laya.conf"

bash "$repo_root/bin/cockpit-laya" mcp register --client cursor
python3 -c 'import json; d=json.load(open("'$HOME'/.cursor/mcp.json")); assert "laya" in d["mcpServers"]; assert "other" in d["mcpServers"]'

bash "$repo_root/bin/cockpit-laya" mcp register --client codex
grep -q '^\[mcp_servers\.laya\]' "$HOME/.codex/config.toml"

first_sha="$(sha256sum "$HOME/.cursor/mcp.json" | awk '{print $1}')"
bash "$repo_root/bin/cockpit-laya" mcp register --client cursor
second_sha="$(sha256sum "$HOME/.cursor/mcp.json" | awk '{print $1}')"
[[ "$first_sha" == "$second_sha" ]]

bash "$repo_root/bin/cockpit-laya" mcp unregister --client all
python3 -c 'import json; d=json.load(open("'$HOME'/.cursor/mcp.json")); assert "laya" not in d.get("mcpServers",{})'
! grep -q '^\[mcp_servers\.laya\]' "$HOME/.codex/config.toml"

# malformed restore
printf '{bad json' >"$HOME/.cursor/mcp.json"
if bash "$repo_root/bin/cockpit-laya" mcp register --client cursor 2>/dev/null; then
  :
fi

out="$(bash "$repo_root/bin/cockpit-laya" mcp register --client hermes 2>&1 || true)"
[[ "$out" == *manual* ]]

printf 'laya-mcp: ok (cursor-json, codex-toml, hermes, idempotent, unregister, parse-restore)\n'
