---
name: cockpit-files
description: Keep Cockpit's Neovim Files page rooted in the active Git worktree and verify that the 2:FILES button opens it.
---

# Files page

Open the page with `cockpit files` or tap the lower Agent chip labeled
`2:FILES`. Verify that a pane has window name `FILES`, role `files`, and the
active worktree path. The Files page is a real top-level window, not a pad
joined into Agent.

Preserve an existing Neovim process and unsaved buffer during layout changes.
Only repair a dead or missing Files pane at an explicit page-open boundary;
never respawn it merely because the bar or Foot chrome was refreshed.
