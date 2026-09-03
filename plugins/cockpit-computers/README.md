# cockpit.computers

`cockpit.computers` is a Cockpit-native plugin with the same manifest shape as
`cockpit.memory`. Its `computers` entrypoint backs the named COMPUTERS page as
the eighth allowed top-level tmux window.

The renderer accepts only the intercom-managed computer receipt, in this order:

1. `~/intercom/computers/receipt.tsv`
2. `computers/receipt.tsv` relative to the current directory

If neither path exists, COMPUTERS exits closed with an explanatory message. It
does not attach to remote hosts, spawn daemons, or synthesize roster rows.
MODELS is a read-only subview (`m`) inside the COMPUTERS pane, not a ninth
window.

See `aspects/cockpit-models.md` for the compiled entry-point contract.
