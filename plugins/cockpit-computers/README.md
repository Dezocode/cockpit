# cockpit.computers

`cockpit.computers` is a Cockpit-native plugin with the same manifest shape as
`cockpit.memory`. Its `computers` entrypoint backs the named COMPUTERS page as
the eighth allowed top-level tmux window.

The renderer accepts intercom-managed node receipts, in this order:

1. `$COCKPIT_INTERCOM_HOME/models/*.json` (default `~/intercom/models/*.json`)
   — one logical node per file; each valid receipt is an independent roster row
2. `$COCKPIT_INTERCOM_HOME/computers/receipt.tsv` (legacy compatibility)
3. `$COCKPIT_PROJECT/models/*.json` (cwd-relative project fallback)
4. `$COCKPIT_PROJECT/computers/receipt.tsv` (cwd-relative project fallback)

Each JSON receipt is a node-local, read-only snapshot. It must contain schema 1,
a node id, and at least one runtime with endpoint, reachability, gateway state, and
model state. A valid JSON receipt produces one roster row; a `tailscale_hostname=`
note (or equivalent) may provide that row's device id while `node` stays the
logical id for the node-control bus. Multiple valid files (for example
`deck.json` and `deck-sol.json`) produce multiple roster rows on the same
physical host. Invalid JSON files are skipped with a visible fail-closed message
and do not invent rows. If every JSON file in the active models directory is
invalid, COMPUTERS exits closed and does not fall through to TSV. It does not
attach to remote hosts, spawn daemons, or dispatch commands. MODELS is a
read-only subview (`m`) inside the COMPUTERS pane, not a ninth window.

See `aspects/cockpit-models.md` for the compiled entry-point contract.
