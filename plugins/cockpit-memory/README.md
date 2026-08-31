# Cockpit memory plugin

`cockpit.memory` is a Cockpit-native plugin. It renders the canonical memory
map stored in the Intercom checkout. It is separate from the Codex marketplace
and from the AGENT runtime slot.

## Source

The diagram path defaults to `~/intercom/memory/cockpit.mmd`. Override the
Intercom root with `COCKPIT_INTERCOM_HOME`.

The plugin fails closed when the file is missing or invalid. It does not scrape
`/workspace/aspects` or synthesize a fallback diagram.

Required subgraph labels: `index`, `intercom`, and `hooks`. Foundry, PiSai, and
MBA references are rejected.

## Commands

```bash
memory status
memory validate
memory render
memory handshake
```

`handshake` prints a one-shot readiness marker for launch coordination.

## Page (deferred)

`bin/cockpit-memory` implements the MEMORY TUI watcher, but session launch,
menu, touch routing, and tmux keybinds are intentionally **not** wired in this
PREP slice. Goal 1 MEMORY stays unapproved until layout and Agent toolbar /
Termius button responsiveness match `v0.1` / `cc4f1ee`. Wiring the MEMORY window
into the live session topology is a separate step after that regression gate.
