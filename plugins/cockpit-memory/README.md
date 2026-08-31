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

## Page

The MEMORY tmux window runs `cockpit-memory`, which watches the same file and
redraws when it changes. Open it from the Cockpit menu or `cockpit-touch
<session> memory`.
