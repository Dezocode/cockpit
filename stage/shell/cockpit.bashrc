# Workspace Cockpit: `cockpit` is the tmux workspace.
# `cockpit agent` jumps to the live Agent pane when tabs/chips are stuck.
# `codex` stays the Codex CLI — never alias it to cockpit.
# The installed `cockpit` executable is canonical; no legacy alias is needed.
unalias cockpit 2>/dev/null || true
# Cockpit reload: canonical live update; preserve every pane process by default.
unalias cpr 2>/dev/null || true
cpr() {
  command -v cockpit >/dev/null 2>&1 || return 0
  cockpit cpr "$@"
}
unalias codex 2>/dev/null || true
