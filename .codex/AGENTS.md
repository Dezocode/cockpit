# Cockpit project instructions

This directory is the canonical Cockpit project. Work from the selected Git
worktree under `/home/dezocode/Work/cockpit`; do not silently fall back to
`/home/dezocode` as the project root.

## Runtime and pages

- The runtime is the existing Codex pane in the `cockpit` tmux session.
- The stable top-level pages are `1:AGENT`, `2:FILES`, `3:DIFF`, `4:MAP`,
  `5:SETUP`, `6:PRS`, and `7:MEMORY`.
- Open Files with `cockpit files` or the lower Agent toolbar chip `2:FILES`.
  The Files pane must remain a real `FILES` window with role `files`; do not
  replace it with a split or a nested terminal.
- Use `cockpit worktree inspect` and `cockpit worktree bind` when changing
  worktrees. A project path passed to `cockpit` must match the runtime's
  selected worktree before attaching.
- To move an existing session, wait until Agent is idle and run
  `cockpit worktree use PATH SESSION --yes --restart-agent --restart-files
  --refresh-derived`; the explicit flags are required because Agent and Files
  processes are replaced.

## Safe changes

- Preserve existing user edits. Do not reset, clean, fetch, push, or commit
  unless the user explicitly requests that exact operation.
- Do not send keys to the live Agent pane while it is cooking. Use an isolated
  tmux socket for tests and benchmarks.
- Do not expose provider tokens, OAuth URLs, auth JSON, or environment secrets.
- Keep hooks idempotent and metadata-only unless an explicit command is
  confirmed. Never create a hook loop by selecting a window from a select hook.
- Keep Foot/Omarchy compatibility: use the existing tmux page row and status
  chrome; do not add a second client, QML surface, or replacement toolbar.

## Native project assets

The `cockpit-native` Codex plugin is sourced from `plugins/cockpit-native` and
its skills are mirrored into `.codex/skills`. The project hook registry is
`.codex/hooks/cockpit-hooks.toml`; install its safe tmux dispatch with
`cockpit-hooks-install`.

Before handoff, run the focused tests, the native plugin validator, and
`tests/test-cockpit-native-integration.sh`. A missing external MEMORY source
is reported as a warning/gate; it must not be “fixed” by fabricating source.
