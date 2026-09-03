---
name: cockpit-foot-omarchy
description: Preserve Cockpit's Foot and Omarchy-compatible tmux chrome while adapting desktop and touch layouts without changing page identity.
---

# Foot and Omarchy

Use the existing `cockpit-adapt` path to refresh status chrome and named page
tabs. Keep `COCKPIT`, `AGENT`, `FILES`, `DIFF`, `MAP`, `SETUP`, `PRS`, and
`MEMORY` labels stable across resize and touch adaptation.

Do not add a second terminal client, QML overlay, or duplicate status row.
Display-only refreshes must preserve the runtime PID and the Files Neovim PID;
test on an isolated tmux socket before touching the live session.
