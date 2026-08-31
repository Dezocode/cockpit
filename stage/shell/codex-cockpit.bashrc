# Workspace Cockpit: `cockpit` is the tmux workspace.
# `cockpit agent` jumps to the live Agent pane when tabs/chips are stuck.
# `codex` stays the Codex CLI — never alias it to cockpit.
alias cockpit='codex-cockpit'
# Cockpit reload: refresh Agent controls and derived views; keep live Vim pages.
unalias cpr 2>/dev/null || true
cpr() {
  local session="${CODEX_COCKPIT_SESSION:-}"
  tmux source-file "$HOME/.config/tmux/codex-cockpit.conf" || return
  if [[ -n "${TMUX:-}" ]]; then
    session="$(tmux display-message -p '#{session_name}' 2>/dev/null || true)"
  fi
  session="${session:-codex-cockpit}"
  command -v codex-cockpit-reload-views >/dev/null 2>&1 || return 0
  codex-cockpit-reload-views "$session"
}
unalias codex 2>/dev/null || true
