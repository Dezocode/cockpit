---
name: cockpit-setup
description: Operate Cockpit's persistent SETUP page for provider auth, models, plugins, project profiles, and validation.
---

# Setup page

Use `cockpit setup` for the persistent `SETUP` page. Its flow owns provider
selection, model state, native Codex plugin discovery, project profile target,
Git target selection, validation, and intercom sync.

Prefer read-only probes and provider-owned login/status commands. Never print
OAuth payloads or auth JSON. A failed external sync should remain a visible
diagnostic while unrelated page routing and Files behavior continue working.
