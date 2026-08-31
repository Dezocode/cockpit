#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")" && pwd)"
bindir="${HOME}/.local/bin"
confdir="${XDG_CONFIG_HOME:-$HOME/.config}"
config_home="${COCKPIT_CONFIG_HOME:-$confdir/cockpit}"
legacy_config_home="${COCKPIT_LEGACY_CONFIG_HOME:-$confdir/codex-cockpit}"
tmuxdir="$confdir/tmux"

mkdir -p "$bindir" "$tmuxdir" \
  "$config_home/providers.d" "$config_home/nvim" \
  "$config_home/plugins/cockpit-cpr" "$config_home/skills.d" \
  "$legacy_config_home/providers.d" "$legacy_config_home/nvim" \
  "$legacy_config_home/plugins/cockpit-cpr" "$legacy_config_home/skills.d"

# The public command and every helper use the cockpit namespace. The old
# codex-cockpit-* files are installed alongside them as compatibility shims.
install -m 0755 "$root/bin/"cockpit* "$bindir/"
install -m 0755 "$root/bin/"codex-cockpit* "$root/bin/codex-mermaid-watch" "$bindir/" 2>/dev/null || true
install -m 0644 "$root/bin/cockpit-lib" "$root/bin/cockpit-auth-lib" \
  "$root/bin/cockpit-agent-lib" "$root/bin/codex-cockpit-lib" \
  "$root/bin/codex-cockpit-auth-lib" "$root/bin/codex-cockpit-agent-lib" \
  "$bindir/"
install -m 0755 "$root/bin/cpr" "$bindir/cpr"

seed_legacy_file() {
  local relative=$1 mode=$2
  [[ -e "$config_home/$relative" ]] && return 0
  [[ -f "$legacy_config_home/$relative" ]] || return 0
  install -m "$mode" "$legacy_config_home/$relative" "$config_home/$relative"
}

seed_legacy_file nvim/cockpit-diff.lua 0644
seed_legacy_file nvim/cockpit-files.lua 0644
seed_legacy_file profile.conf 0644
seed_legacy_file cockpit.conf 0644
seed_legacy_file providers.conf 0644
seed_legacy_file state 0600
seed_legacy_file gist.id 0600
shopt -s nullglob
for legacy_provider in "$legacy_config_home/providers.d/"*.conf; do
  provider_file="$config_home/providers.d/${legacy_provider##*/}"
  [[ -e "$provider_file" ]] || install -m 0644 "$legacy_provider" "$provider_file"
done
shopt -u nullglob

normalize_canonical_namespace() {
  local file=$1 tmp
  # Only rewrite the old built-in path in the default XDG location. Custom
  # paths and user-selected skills directories are left exactly as authored.
  [[ "$config_home" == "$HOME/.config/cockpit" && -f "$file" ]] || return 0
  if ! grep -Fq '~/.config/codex-cockpit' "$file"; then
    return 0
  fi
  tmp="${file}.cockpit-migrate.$$"
  sed -e 's#~/.config/codex-cockpit#~/.config/cockpit#g' \
    -e 's#Codex Cockpit#Cockpit#g' "$file" >"$tmp"
  chmod --reference="$file" "$tmp" 2>/dev/null || true
  mv "$tmp" "$file"
}

normalize_canonical_namespace "$config_home/profile.conf"
normalize_canonical_namespace "$config_home/providers.conf"

normalize_canonical_commands() {
  local file=$1 tmp
  [[ "$config_home" == "$HOME/.config/cockpit" && -f "$file" ]] || return 0
  if ! grep -Eq 'codex-cockpit-|codex-mermaid-watch' "$file"; then
    return 0
  fi
  tmp="${file}.cockpit-commands.$$"
  sed -e 's/codex-cockpit-/cockpit-/g' \
    -e 's/codex-mermaid-watch/cockpit-mermaid-watch/g' "$file" >"$tmp"
  chmod --reference="$file" "$tmp" 2>/dev/null || true
  mv "$tmp" "$file"
}

normalize_canonical_commands "$config_home/providers.conf"

# User-owned config is only seeded when absent. Templates and plugin code are
# updated in the canonical tree; the legacy tree is retained for old scripts.
install -m 0644 "$root/plugins/cockpit-cpr/plugin.conf" "$root/plugins/cockpit-cpr/README.md" \
  "$config_home/plugins/cockpit-cpr/"
install -m 0755 "$root/plugins/cockpit-cpr/cpr" \
  "$config_home/plugins/cockpit-cpr/cpr"
if [[ ! -f "$legacy_config_home/plugins/cockpit-cpr/plugin.conf" ]]; then
  install -m 0644 "$root/plugins/cockpit-cpr/plugin.conf" "$legacy_config_home/plugins/cockpit-cpr/plugin.conf"
fi
if [[ ! -f "$legacy_config_home/plugins/cockpit-cpr/README.md" ]]; then
  install -m 0644 "$root/plugins/cockpit-cpr/README.md" "$legacy_config_home/plugins/cockpit-cpr/README.md"
fi
if [[ ! -f "$legacy_config_home/plugins/cockpit-cpr/cpr" ]]; then
  install -m 0755 "$root/plugins/cockpit-cpr/cpr" "$legacy_config_home/plugins/cockpit-cpr/cpr"
fi

if [[ ! -f "$config_home/cockpit.bashrc" ]]; then
  install -m 0644 "$root/stage/shell/cockpit.bashrc" \
    "$config_home/cockpit.bashrc"
fi
if [[ ! -f "$legacy_config_home/codex-cockpit.bashrc" ]]; then
  install -m 0644 "$root/stage/shell/cockpit.bashrc" \
    "$legacy_config_home/codex-cockpit.bashrc"
fi

if [[ ! -f "$config_home/nvim/cockpit-diff.lua" ]]; then
  install -m 0644 "$root/stage/nvim/lua/config/cockpit-diff.lua" \
    "$config_home/nvim/cockpit-diff.lua"
fi
if [[ ! -f "$config_home/nvim/cockpit-files.lua" ]]; then
  install -m 0644 "$root/stage/nvim/lua/config/cockpit-files.lua" \
    "$config_home/nvim/cockpit-files.lua"
fi
if [[ ! -f "$config_home/profile.conf" ]]; then
  install -m 0644 "$root/stage/profile/profile.conf" "$config_home/profile.conf"
fi
if [[ ! -f "$config_home/cockpit.conf" ]]; then
  install -m 0644 "$root/stage/profile/cockpit.conf" "$config_home/cockpit.conf"
fi
if [[ ! -f "$config_home/skills.d/README.txt" ]]; then
  install -m 0644 "$root/stage/profile/skills.d/README.txt" \
    "$config_home/skills.d/README.txt"
fi
if [[ ! -f "$config_home/providers.conf" ]]; then
  install -m 0644 "$root/stage/auth/providers.conf" "$config_home/providers.conf"
fi
if compgen -G "$root/stage/auth/providers.d/*.conf" >/dev/null; then
  for provider_template in "$root/stage/auth/providers.d/"*.conf; do
    provider_file="$config_home/providers.d/${provider_template##*/}"
    [[ -f "$provider_file" ]] || install -m 0644 "$provider_template" "$provider_file"
  done
fi

# The canonical overlay is always available. Keep the old overlay untouched
# when present, because users may have customized it and old hooks still read
# it. A new legacy install receives the same compatible overlay as a fallback.
canonical_overlay="$tmuxdir/cockpit.conf"
legacy_overlay="$tmuxdir/codex-cockpit.conf"
if [[ ! -f "$canonical_overlay" ]]; then
  install -m 0644 "$root/stage/tmux/cockpit.conf" "$canonical_overlay"
fi
if [[ ! -f "$legacy_overlay" ]]; then
  install -m 0644 "$root/stage/tmux/cockpit.conf" "$legacy_overlay"
fi
normalize_canonical_commands "$canonical_overlay"

if [[ -f "$confdir/tmux/tmux.conf" ]] && ! grep -Fq "$canonical_overlay" "$confdir/tmux/tmux.conf"; then
  printf '\n# Cockpit overlay\nif-shell '\''[ -f %s ]'\'' '\''source-file %s'\''\n' \
    "$canonical_overlay" "$canonical_overlay" >>"$confdir/tmux/tmux.conf"
fi

shellrc="${COCKPIT_SHELL_RC:-${HOME}/.bashrc}"
# Existing installations may already contain the old reload function. Append
# a separately marked canonical definition instead of rewriting shellrc.
cpr_plugin_marker='# Cockpit cpr plugin'
if [[ -f "$shellrc" ]] &&
  ! grep -Fqx "$cpr_plugin_marker" "$shellrc"; then
  printf '\n%s\n' "$cpr_plugin_marker" >>"$shellrc"
  printf '%s\n' \
    'unalias cockpit 2>/dev/null || true' \
    'cpr() {' \
    '  command -v cockpit >/dev/null 2>&1 || return 0' \
    '  cockpit cpr "$@"' \
    '}' >>"$shellrc"
fi

# Upgrade an active installation in place. Renaming the old session keeps
# Agent/FILES alive; only derived views are refreshed afterward so their old
# command-line session argument cannot strand the toolbar.
session="${COCKPIT_SESSION:-${CODEX_COCKPIT_SESSION:-cockpit}}"
migrated=0
if command -v tmux >/dev/null 2>&1; then
  if [[ "$session" == cockpit ]] &&
    ! tmux has-session -t "$session" 2>/dev/null &&
    tmux has-session -t codex-cockpit 2>/dev/null; then
    tmux rename-session -t codex-cockpit cockpit 2>/dev/null || true
    tmux has-session -t cockpit 2>/dev/null && migrated=1
  fi
  if tmux has-session -t "$session" 2>/dev/null; then
    "$bindir/cockpit-apply" "$session" || true
    if ((migrated)); then
      "$bindir/cockpit-reload-views" "$session" >/dev/null 2>&1 || true
    fi
  fi
fi

printf 'Installed to %s\nRun: cockpit   (workspace)\n      cockpit agent   (jump to live Agent pane)\n      codex           (Codex CLI)\nProfile sync: cockpit config push|pull (your gh login, secret gist)\nCanonical config: %s\n' \
  "$bindir" "$config_home"
