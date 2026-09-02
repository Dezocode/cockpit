---
name: cockpit-regression
description: Validate Cockpit changes against page topology, Files reachability, PID preservation, hooks, plugin loading, and external-source warnings.
---

# Cockpit regression checks

Run `bash -n bin/*`, `git diff --check`, focused setup/auth/memory/plugin tests,
`tests/test-termius-touch.sh`, and the native integration benchmark. The
benchmark must exercise every registered skill and hook on an isolated tmux
socket and report an observable effect plus elapsed time.

For live verification, inspect before mutating. Confirm seven named windows,
one runtime, one Files pane, the lower `2:FILES` chip, and unchanged runtime
and Files PIDs after display-only reloads. Treat an incomplete external MEMORY
source as a warning/gate, never as a reason to fake source data.
