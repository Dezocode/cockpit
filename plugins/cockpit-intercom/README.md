# cockpit.intercom

Read-only first-launch readiness and sync gate for the intercom-managed
`cockpit.memory` page. `status` and `sync` verify `GOAL.md`, `HANDSHAKE.md`,
and `memory/cockpit.mmd`, including the `index`, `intercom`, `handshake`, and
`hooks` subgraphs. The plugin never clones, fetches, pushes, or edits the
managed intercom projection.
