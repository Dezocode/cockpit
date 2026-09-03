---
name: cockpit-memory
description: Inspect Cockpit's managed memory source and fail closed when an external sync is incomplete.
---

# Memory page

Use `cockpit memory` to open the `MEMORY` page and inspect the managed source
under the active project. The source is authoritative only when its required
subgraphs and sync handshake are present.

If a sync reports an incomplete managed source, show the missing requirement
and preserve the warning. Do not fabricate a handshake, copy secrets, or
silently replace external memory with local guesses.
