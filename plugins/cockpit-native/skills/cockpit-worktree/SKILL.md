---
name: cockpit-worktree
description: Inspect, add, and bind Git worktrees to a Cockpit tmux session without accidentally targeting the main repository.
---

# Cockpit worktrees

Use `cockpit worktree inspect PATH` before changing project context. Confirm
`git_root`, `git_common_dir`, `git_dir`, `branch`, and `worktree_path`; a linked
worktree must remain distinct from its common Git directory.

Use `cockpit worktree bind PATH SESSION` to refresh tmux user-option metadata.
Binding is metadata-only and preserves a cooking Agent and open Neovim buffer.
To deliberately move an existing session, wait for a safe runtime boundary and
use `cockpit worktree use PATH SESSION --yes --restart-agent --restart-files
--refresh-derived`; the explicit flags acknowledge the process restarts.
Adding a worktree requires an explicit `--branch NAME --yes`; the command
refuses existing target paths and does not fetch, push, reset, or clean.

After binding, check `@cockpit_git_worktree_path` and `@cockpit_git_branch` in
the session before routing Agent, Files, or Diff pages.
