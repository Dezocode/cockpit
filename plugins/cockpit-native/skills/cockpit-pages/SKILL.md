---
name: cockpit-pages
description: Route work through Cockpit's stable nine-page tmux topology while preserving named tabs and the lower Agent toolbar.
---

# Cockpit pages

The public page row is `1:AGENT`, `2:FILES`, `3:DIFF`, `4:MAP`, `5:SETUP`,
`6:PRS`, `7:MEMORY`, `8:COMPUTERS`, and `9:BENCH`. Route with `cockpit agent`,
`cockpit files`, `cockpit diff`, `cockpit map`, `cockpit setup`, `cockpit prs`,
`cockpit memory`, `cockpit computers`, or `cockpit bench`.

The lower Agent toolbar must contain `2:FILES` between the provider chip and
MEMORY. Use the existing `cockpit-touch` routing and `@cockpit_role` metadata;
do not replace a page with an unlabelled split, nested tmux client, or second
runtime. BENCH is a named window only — not a toolbar chip.
