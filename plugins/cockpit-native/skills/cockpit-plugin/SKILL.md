---
name: cockpit-plugin
description: Develop, validate, register, and activate the repository's native Codex Cockpit plugin without conflating it with the shell plugin registry.
---

# Native Cockpit plugin

The native plugin manifest is `plugins/cockpit-native/.codex-plugin/plugin.json`
and the repository marketplace is `.agents/plugins/marketplace.json`. Validate
with the plugin-creator validator, then register the explicit local marketplace
and install `cockpit-native@personal` through `codex plugin`.

Keep `bin/cockpit-plugin`'s `cockpit.cpr`, `cockpit.memory`, `cockpit.computers`,
`cockpit.bench`, and `cockpit.intercom` registry separate from native Codex plugin discovery. When
iterating, update the plugin cachebuster and reinstall; a new Codex thread is
needed to load new skills.
