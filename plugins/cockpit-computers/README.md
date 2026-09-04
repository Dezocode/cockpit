# cockpit.computers

`cockpit.computers` is a Cockpit-native plugin with the same manifest shape as
`cockpit.memory`. Its `computers` entrypoint backs the named COMPUTERS page as
the eighth allowed top-level tmux window.

The renderer accepts only the intercom-managed computer receipt, in this order:

1. `~/intercom/models/deck.json`
2. `~/intercom/computers/receipt.tsv` (legacy compatibility)
3. `models/deck.json` relative to the current project
4. `computers/receipt.tsv` relative to the current project

The JSON receipt is a node-local, read-only snapshot. It must contain schema 1,
a node, and at least one runtime with endpoint, reachability, gateway state, and
model state. A valid JSON receipt produces one roster row; a hostname note may
provide that row's device id. If the preferred JSON receipt exists but is
invalid, COMPUTERS exits closed and does not fall through to a TSV or invent a
row. It does not attach to remote hosts, spawn daemons, or dispatch commands.
MODELS is a read-only subview (`m`) inside the COMPUTERS pane, not a ninth
window.

See `aspects/cockpit-models.md` for the compiled entry-point contract.
