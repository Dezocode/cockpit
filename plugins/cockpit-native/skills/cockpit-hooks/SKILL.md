---
name: cockpit-hooks
description: Install and audit idempotent Cockpit tmux and project hooks without creating recursive page-routing loops.
---

# Cockpit hooks

The project registry is `.codex/hooks/cockpit-hooks.toml`; install the fixed
global slots with `cockpit-hooks-install`. The dispatcher records event counts,
refreshes worktree/agent metadata, and may wake an already selected watcher.

Hooks must not select windows, split panes, respawn Agent, or kill sessions.
After installation inspect `tmux show-hooks -g` and confirm one fixed slot per
event. Re-running the installer must leave the count and page topology stable.
