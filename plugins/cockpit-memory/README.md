# cockpit.memory

`cockpit.memory` is a Cockpit-native plugin. It is separate from the Codex
marketplace plugin registry.

The MEMORY tab reads `memory/cockpit.mmd` from the Intercom clone. Clone
location defaults to `~/intercom` and can be overridden with
`COCKPIT_INTERCOM_HOME`.

The plugin fails closed when the diagram is missing. It never reads
`/workspace/aspects` or project-local Mermaid fallbacks. Rendered output
includes only the `index`, `intercom`, and `hooks` subgraphs. Subgraphs named
`Foundry`, `PiSai`, or `MBA` are excluded.

Fetch and sync of the Intercom repository remain the live Agent's job through
`cockpit.intercom`. MEMORY only reads the on-disk clone.

## Commands

```bash
memory path                 # resolved memory/cockpit.mmd path
memory check                # fail closed when missing or invalid
memory show                 # filtered diagram on stdout
```

## Registry

```bash
cockpit plugin list
cockpit plugin run cockpit.memory check
```
