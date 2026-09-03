---
name: cockpit-diff
description: Inspect scoped Git status, staged changes, worktree changes, and untracked files in the active Cockpit worktree.
---

# Diff page

Use `cockpit diff` after confirming the session's `@cockpit_git_worktree_path`.
The page should show staged, unstaged, and untracked changes scoped to the
selected worktree or subdirectory, without changing the index.

Keep status metadata useful when the page is hidden. Do not run reset, clean,
checkout, fetch, or push as part of a Diff inspection. A missing Git root is a
diagnostic state, not permission to initialize or rewrite another directory.
