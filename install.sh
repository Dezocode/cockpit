#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")" && pwd)"
bindir="${HOME}/.local/bin"
confdir="${HOME}/.config"
mkdir -p "$bindir" "$confdir/tmux" "$confdir/codex-cockpit/providers.d" "$confdir/codex-cockpit/nvim"
install -m 0755 "$root/bin/"codex-cockpit* "$root/bin/codex-mermaid-watch" "$bindir/" 2>/dev/null || true
install -m 0644 "$root/bin/codex-cockpit-lib" "$root/bin/codex-cockpit-auth-lib" "$bindir/"
install -m 0644 "$root/stage/shell/codex-cockpit.bashrc" \
  "$confdir/codex-cockpit/codex-cockpit.bashrc"
install -m 0644 "$root/stage/tmux/codex-cockpit.conf" "$confdir/tmux/codex-cockpit.conf"
install -m 0644 "$root/stage/nvim/lua/config/cockpit-diff.lua" \
  "$confdir/codex-cockpit/nvim/cockpit-diff.lua"
install -m 0644 "$root/stage/nvim/lua/config/cockpit-files.lua" \
  "$confdir/codex-cockpit/nvim/cockpit-files.lua"
if [[ ! -f "$confdir/codex-cockpit/providers.conf" ]]; then
  install -m 0644 "$root/stage/auth/providers.conf" "$confdir/codex-cockpit/providers.conf"
fi
if compgen -G "$root/stage/auth/providers.d/*.conf" >/dev/null; then
  install -m 0644 "$root/stage/auth/providers.d/"*.conf "$confdir/codex-cockpit/providers.d/"
fi
if [[ -f "$confdir/tmux/tmux.conf" ]] && ! grep -q 'codex-cockpit.conf' "$confdir/tmux/tmux.conf"; then
  printf '\n# Codex Cockpit overlay\nif-shell '\''[ -f ~/.config/tmux/codex-cockpit.conf ]'\'' '\''source-file ~/.config/tmux/codex-cockpit.conf'\''\n' >>"$confdir/tmux/tmux.conf"
fi
shellrc="${COCKPIT_SHELL_RC:-${HOME}/.bashrc}"
shell_marker='# Codex Cockpit reload function'
if [[ -f "$shellrc" ]] && ! grep -Fqx "$shell_marker" "$shellrc"; then
  printf '\n%s\n' "$shell_marker" >>"$shellrc"
  printf '%s\n' \
    'cpr() {' \
    '  local session="${CODEX_COCKPIT_SESSION:-}"' \
    '  unalias cpr 2>/dev/null || true' \
    '  tmux source-file "$HOME/.config/tmux/codex-cockpit.conf" || return' \
    '  if [[ -n "${TMUX:-}" ]]; then' \
    '    session="$(tmux display-message -p '\''#{session_name}'\'' 2>/dev/null || true)"' \
    '  fi' \
    '  session="${session:-codex-cockpit}"' \
    '  command -v codex-cockpit-reload-views >/dev/null 2>&1 || return 0' \
    '  codex-cockpit-reload-views "$session"' \
    '}' >>"$shellrc"
fi
install -m 0755 "$root/bin/codex-cockpit-config" "$bindir/codex-cockpit-config" 2>/dev/null || true
ln -sf codex-cockpit "$bindir/cockpit"
if tmux has-session -t "${CODEX_COCKPIT_SESSION:-codex-cockpit}" 2>/dev/null; then
  "$bindir/codex-cockpit-apply" "${CODEX_COCKPIT_SESSION:-codex-cockpit}" || true
fi
printf 'Installed to %s\nRun: cockpit   (workspace)\n      cockpit agent   (jump to live Agent pane)\n      codex           (Codex CLI)\nProfile sync: cockpit config push|pull (your gh login, secret gist)\n' "$bindir"
