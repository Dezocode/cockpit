#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")" && pwd)"
bindir="${HOME}/.local/bin"
confdir="${HOME}/.config"
mkdir -p "$bindir" "$confdir/tmux" "$confdir/codex-cockpit/providers.d"
install -m 0755 "$root/bin/"codex-cockpit* "$root/bin/codex-mermaid-watch" "$bindir/" 2>/dev/null || true
install -m 0644 "$root/bin/codex-cockpit-lib" "$root/bin/codex-cockpit-auth-lib" "$bindir/"
install -m 0644 "$root/stage/tmux/codex-cockpit.conf" "$confdir/tmux/codex-cockpit.conf"
if [[ ! -f "$confdir/codex-cockpit/providers.conf" ]]; then
  install -m 0644 "$root/stage/auth/providers.conf" "$confdir/codex-cockpit/providers.conf"
fi
if [[ -f "$confdir/tmux/tmux.conf" ]] && ! grep -q 'codex-cockpit.conf' "$confdir/tmux/tmux.conf"; then
  printf '\n# Codex Cockpit overlay\nif-shell '\''[ -f ~/.config/tmux/codex-cockpit.conf ]'\'' '\''source-file ~/.config/tmux/codex-cockpit.conf'\''\n' >>"$confdir/tmux/tmux.conf"
fi
install -m 0755 "$root/bin/codex-cockpit-config" "$bindir/codex-cockpit-config" 2>/dev/null || true
ln -sf codex-cockpit "$bindir/cockpit"
printf 'Installed to %s\nRun: cockpit\nProfile sync: cockpit config push|pull (your gh login, secret gist)\n' "$bindir"
