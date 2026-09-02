---
name: cockpit-project
description: Launch or attach Cockpit with a specific project root and prevent a live home-directory session from silently serving the wrong project.
---

# Cockpit project root

Use `cockpit /absolute/project/path` for a new workspace. Cockpit resolves a
Git subdirectory to its worktree root and passes the same root to the Codex
runtime with native `-C` plus the tmux pane cwd.

If `cockpit` reports an existing-session project mismatch, do not bypass it by
attaching manually. Inspect the live session, wait for a safe Agent boundary,
then use the explicit worktree binding/switch workflow. The runtime, Files,
Diff, Map, and Memory pages must describe one worktree.
