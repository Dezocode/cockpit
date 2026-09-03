---
name: cockpit-computers
description: Inspect Cockpit's managed computer receipt and fail closed when the intercom roster is incomplete.
---

# Computers page

Use `cockpit computers` to open the `COMPUTERS` page and inspect the managed
receipt under the active project. The receipt is authoritative only when it
exists at the intercom or project fallback path.

MODELS is the `m` subview inside COMPUTERS (not a ninth tmux window). If the
receipt is missing or invalid, show the error and preserve fail-closed behavior.
Do not attach to remote hosts, spawn cross-device daemons, or synthesize roster
rows.
