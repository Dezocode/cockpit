# cockpit.memory

`cockpit.memory` is a Cockpit-native plugin with the same manifest shape as
`cockpit.intercom`. Its `memory` entrypoint renders the named MEMORY page as
the seventh allowed top-level tmux window, so MAP remains one pane.

The renderer accepts only the intercom-managed memory file, in this order:

1. `~/intercom/memory/cockpit.mmd`
2. `memory/cockpit.mmd` relative to the current directory

If neither path exists, MEMORY exits closed with an explanatory message. It
does not synthesize a graph or consult another workspace tree. The Mermaid
source is passed to the same local Show Me adapter used by MAP, preserving the
authored `index`, `intercom`, `handshake`, and `hooks` subgraphs. If the managed
source is absent or incomplete, MEMORY exits closed with an explanatory message
rather than synthesizing a graph.
