---
name: cockpit-map
description: Use Cockpit's local Mermaid Map page to understand project topology without adding a nested visual surface.
---

# Map page

Use `cockpit map` for the named `MAP` page and `cockpit-showmegraphs` for a
local Mermaid view when requested. Keep the map rooted at the active project
and worktree; treat external or missing source as unavailable rather than
inventing graph nodes.

The Foot/Omarchy layout adapter may change chrome, but MAP remains a stable
top-level page and must not steal, split, or restart the Agent pane.
