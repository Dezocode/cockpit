# RFC: Cockpit profile platform and Sai Harness distribution

Status: proposed implementation contract

## Objective

Cockpit is the open-source tmux agent-workstation runtime. Sai Harness is a first-party branded Cockpit distribution/profile that composes Cockpit into Sai's organizational multi-agent, multi-device operating environment.

The implementation must preserve Cockpit as the reusable mechanism layer while moving Sai-specific policy, branding, orchestration, workflows, automations, and organization semantics into a profile/distribution layer.

This RFC is intentionally broader than a theme change. It defines the architectural boundary for Cockpit, the Sai Harness product built on top of it, the plugin model, the Omarchy integration contract, the cross-platform contract, and the no-regression validation requirements.

## Non-negotiable requirements

1. **Canonical source rebrand: `codex-cockpit` -> `cockpit`.** The repository, runtime, executable names, canonical tmux session, config paths, helper names, environment variables, source identifiers, command strings, generated files, installer output, tests, and user-facing product language must use `cockpit` as the authoritative name. Legacy naming must not remain an authoritative implementation path or compatibility namespace. Historical references may exist only where necessary in migration notes/changelog/test fixtures; new runtime behavior must not depend on the old name.
2. **Zero regression of current Cockpit features.** The current AGENT, FILES, DIFF, MAP, MEMORY, SETUP, and PRS pages; provider/model switching; OAuth/setup flows; Git targets; CPR behavior; profile validation; native Codex plugin browsing; GitHub flows; event-driven refresh; mouse/keyboard behavior; and current launch/reattach behavior remain functional.
3. **Termius touch is a first-class supported interaction mode.** Preserve the current full-screen mobile tab flow, bottom navigation, large Agent toolbar touch zones, PTY bridge behavior for Termius mouse packets, tap-vs-key profile behavior, no-BEL/no-haptic behavior, and safe `cockpit` / `cockpit agent` reattach path.
4. **Omarchy/Foot remains the native reference environment.** Cockpit should feel native on Omarchy with Foot and integrate with Omarchy's current plugin standard rather than relying only on ad-hoc launch bindings.
5. **Cockpit must also run on Ubuntu and macOS.** Omarchy-specific integrations must be adapters, not hard dependencies of core runtime behavior.
6. **Feature validation is a release gate.** Existing tests remain authoritative and are expanded into a platform/interaction validation matrix. No rebrand, plugin, profile, or Sai Harness work may silently remove a working feature.
7. **Cockpit must be extensible by plugins and external open-source programs.** A plugin may add providers, pages, commands, workflows, services, or safely managed nested-pane applications, with explicit dependency and lifecycle declarations.
8. **Published profiles/flows are secret-free by construction.** Profiles declare capabilities and authentication requirements, not credential values. GitHub actions are resolved against the locally authenticated `gh` identity and its available scopes/capabilities.

## Product boundary

### Cockpit owns mechanisms

Cockpit should own:

- tmux session/runtime lifecycle
- browser-like page/router primitives
- pane/tab primitives
- desktop/touch presentation modes
- provider adapter API
- model catalog/native-picker interface
- auth/capability resolution
- Git/GitHub workspace context
- profile loading
- branding/theme primitives
- plugin loading and lifecycle
- nested-pane application hosting
- workflow/automation execution primitives
- install/update/audit/validation
- secret-free profile packaging and publication
- platform adapters for Omarchy/Foot, generic Linux/Ubuntu, macOS, and Termius SSH clients

### Sai Harness owns product semantics

Sai Harness should own:

- Sai branding and terminology
- Sai navigation/default page composition
- Pi CLI provider enablement/configuration
- Sai organizational Intercom
- device graph and agent graph
- cross-device agent/session routing
- multi-agent orchestration
- Sai workflows and automations
- Sai policy/default capability sets
- Sai-specific pages such as organization, agents, devices, intercom, and automations

The architectural invariant is:

> Cockpit owns mechanisms. Sai Harness owns composition, policy, organization semantics, and product identity.

Sai-specific requirements that expose a generally useful mechanism should be implemented as a Cockpit extension point, not as a permanent Sai branch in core runtime code.

## Profile and distribution model

A Cockpit profile is a portable declarative configuration. A Cockpit distribution is a profile plus optional extensions, defaults, branding, and packaging.

Sai Harness is both:

```text
Cockpit runtime
    + Sai Harness profile
    + Sai extensions
    + Sai defaults/branding
    = Sai Harness distribution
```

A user should ultimately be able to install a profile into Cockpit or launch a packaged distribution that resolves to the same underlying runtime contract.

Illustrative profile structure:

```text
sai-harness/
├── profile.toml
├── branding/
│   ├── theme.toml
│   ├── logo.*
│   └── terminology.toml
├── providers/
│   └── pi.toml
├── pages/
│   ├── organization.toml
│   ├── agents.toml
│   ├── devices.toml
│   ├── intercom.toml
│   └── automations.toml
├── workflows/
├── automations/
├── policies/
└── commands/
```

Illustrative profile metadata:

```toml
[profile]
id = "sai-harness"
name = "Sai Harness"
runtime = "cockpit"
schema = 1

[brand]
product_name = "Sai Harness"
short_name = "Sai"
home_title = "SAI"
footer_name = "SAI HARNESS"

[providers]
enabled = ["codex", "pi", "anthropic", "grok", "cursor", "open-source"]
```

Branding must be first-class configuration rather than hard-coded replacement strings so other users can safely publish their own branded Cockpit distributions without forking the core runtime.

## Capability-addressed auth and secret-free publication

Profiles and workflows must request capabilities, never embed credentials.

Example:

```yaml
requires:
  - capability: github.pull_request.read
  - capability: github.pull_request.write
  - capability: ai.agent
  - capability: shell.execute
```

Cockpit resolves those requirements locally against the currently authenticated identity/provider and local policy.

The public profile format may contain:

- provider names
- page topology
- commands
- workflow definitions
- capability requirements
- environment variable names
- secret references
- dependency declarations

It must not contain token values, auth files, private gists, or copied provider credentials.

Profile publication should eventually support validation/audit/pack/publish operations and reject likely secrets before publication.

## Provider abstraction and Pi CLI

Pi must be integrated as a normal Cockpit provider, not as Sai-only branching throughout core code.

Provider adapters should expose a common set of optional capabilities such as:

- `ai.chat`
- `ai.agent`
- `ai.agent.parallel`
- `model.list`
- `model.select`
- `auth.status`
- `auth.start`
- `project.detect`
- `project.validate`

Flows should target capabilities where possible so Codex, Pi, Claude, Grok, Cursor, or future providers can satisfy the same workflow step without rewriting the workflow engine.

## Sai Intercom and distributed orchestration

Sai Harness should model agents and devices independently rather than permanently binding an agent identity to one process or host.

Core entities:

```text
Organization
├── Devices
├── Agents
├── Sessions
├── Channels
├── Workflows
├── Automations
└── Artifacts
```

Agent/device relationships are many-to-many through sessions. Intercom messages should carry sufficient routing and provenance metadata for cross-device orchestration, including sender, recipient, organization, thread/task, device, session, payload/artifact references, timestamp, causality, authorization, and delivery state.

This allows workflows such as researcher -> architect -> implementer -> reviewer -> GitHub -> human approval to span different providers and machines without making the terminal session itself the identity boundary.

## MEMORY page (goal 1 prep)

MEMORY is a first-class Cockpit page alongside AGENT, FILES, DIFF, MAP, SETUP, and PRS. It uses the same TUI contract as MAP (Show Me / Mermaid rendering, event-driven refresh, idle when off-screen). There is no stripped fallback that substitutes project-local diagrams or scraped workspace aspects.

### Source contract

- Diagram source: `memory/cockpit.mmd` inside the Intercom clone.
- Default clone path: `~/intercom` (`COCKPIT_INTERCOM_HOME` override).
- Fail closed when the file is missing or unreadable. The MEMORY pane shows an explicit error and does not fall back to `/workspace/aspects` or any project-local `*.mmd` search.
- Allowed subgraphs only: `index`, `intercom`, `hooks`. Subgraphs named `Foundry`, `PiSai`, or `MBA` must never appear in rendered output.

### Plugin contract

`cockpit.memory` is a Cockpit-native plugin (not a Codex marketplace plugin). Manifest shape matches `plugins/cockpit-intercom`:

```ini
id=cockpit.memory
type=cockpit
entrypoint=memory
```

The plugin resolves the Intercom memory path, validates presence, filters the diagram to the three allowed subgraphs, and exposes `check` / `show` commands for tests and the MEMORY watcher. Fetch/sync of the Intercom clone remains the pane Agent's job via `cockpit.intercom`; MEMORY only reads the on-disk clone.

### Session wiring

New sessions create a `MEMORY` tmux window tagged `@cockpit_role memory`, launched by `cockpit-memory-watch`. Touch navigation, wake/reload, audit topology checks, and CPR preservation treat MEMORY like MAP: a derived view that may be explicitly refreshed with `--refresh-derived` but is not respawned during ordinary CPR apply.

## Cockpit plugin model

Cockpit's plugin system is distinct from Omarchy's shell plugin format.

Cockpit plugins should be able to contribute one or more of:

- provider adapters
- pages/tabs (for example `cockpit.memory` backing the MEMORY tab)
- commands
- workflow nodes
- automation triggers/actions
- background services
- nested-pane applications
- validators/auditors

### Nested open-source applications

Cockpit should permit third-party/open-source terminal programs to be hosted in managed nested panes without becoming hard-coded core dependencies.

A nested-pane plugin should declare:

- executable/dependency names
- supported platforms
- installation guidance, not silent privilege escalation
- launch command and arguments
- working-directory policy
- required environment/capabilities
- pane sizing/minimum dimensions
- input mode expectations (keyboard/mouse/touch)
- lifecycle/cleanup behavior
- whether state survives tab switches/reloads
- whether network access or external services are required
- license/upstream metadata

Cockpit owns pane lifecycle and containment. The hosted application remains an upstream dependency and should not be copied or modified unnecessarily.

## Omarchy plugin standard

Cockpit must ship an Omarchy/Quattro integration that conforms to the current official plugin contract documented at:

- https://plugins.omarchy.org/develop.html
- https://plugins.omarchy.org/publish.html

As of the current stable documentation, an Omarchy plugin uses a namespaced `manifest.json` with `schemaVersion`, `id`, `name`, `version`, `author`, `description`, `kinds`, and `entryPoints`; the declared kind and entry point must agree; referenced files must be safe relative paths and exist; third-party IDs cannot use the `omarchy.*` namespace; plugin folders cannot contain symlinks; and validation uses `omarchy plugin validate` plus `qmllint` against the Omarchy shell imports.

The publication contract additionally requires a public GitHub repository, valid root manifest, README/license, and safe install/removal instructions.

Omarchy plugins execute unsandboxed in the user's long-running shell process. Therefore the Cockpit Omarchy integration must be thin, auditable, and explicit about every dependency/command. It must not launch a second Quickshell instance.

The Omarchy adapter should invoke/route into the Cockpit runtime rather than reimplement Cockpit's page system in QML. Omarchy-specific QML is an integration surface; Cockpit remains the tmux runtime.

Acceptance for Omarchy integration includes:

- valid namespaced manifest
- correct kind/entry point mapping
- `omarchy plugin validate` passes
- relevant QML passes `qmllint -I "$OMARCHY_PATH/shell" ...`
- enable/disable/re-enable works
- shell restart works
- removal is clean
- install/removal and dependencies are documented
- no second Quickshell process is created
- existing `omarchy launch tui cockpit` path remains functional unless deliberately superseded by an equivalent validated route

## Platform contract

### Omarchy + Foot

This is the reference desktop environment and must retain:

- current Foot/Wayland detection
- desktop 2x2 pad behavior
- top status/chrome
- mouse and keyboard navigation
- Omarchy colors integration
- native launch flow
- current provider/agent/model/setup behaviors

### Ubuntu / generic Linux

Cockpit core must run without Omarchy or Foot. Dependencies should be detected explicitly. Omarchy-only color/launch APIs must degrade to generic terminal/tmux behavior rather than failing core startup.

Linux-specific facilities such as `inotify` must live behind an adapter boundary when they affect portability.

### macOS

Cockpit must support macOS with tmux and a compatible terminal. Implementation must not assume GNU-only command flags, Linux-only procfs paths, Wayland, `inotify`, `tailscaled` process ancestry, or Omarchy configuration paths in core behavior.

Where platform-specific functionality is necessary, provide a backend/adapter and a deterministic fallback. File watching, executable discovery, path resolution, process inspection, clipboard/open behavior, and terminal capability detection require explicit macOS validation.

### Termius / mobile SSH

Termius is not merely a reduced desktop layout. Preserve the established touch contract:

- full-screen tabs
- bottom canonical page navigation
- four large Agent toolbar touch zones
- touch-safe setup/model/provider flows
- mouse packet normalization through the bundled PTY bridge
- no accidental BEL/title-sequence haptics
- taps select; keys forward without stealing active typing
- `cockpit` and `cockpit agent` reattach paths
- small endpoint sizing remains authoritative for mobile fit

## Zero-regression validation contract

The current test suite already contains coverage for profile, auth/setup, CPR, setup flows, Agent switching, and Termius touch. These tests remain release gates and should be expanded rather than replaced.

Every implementation slice under this RFC must prove that it does not regress:

- AGENT page
- FILES page
- DIFF page and scoped/event-driven behavior
- MAP page
- MEMORY page
- SETUP page
- PRS page
- keyboard navigation
- mouse navigation
- Termius touch navigation
- Termius haptic/BEL suppression
- provider switching
- model picker/native picker
- provider auth state and OAuth flow
- GitHub auth/PR flow
- Git target selection/init
- profile detect/validate/apply
- CPR plan/apply behavior
- plugin list/install flows
- agent restart/reattach
- status/chrome state
- idle/detached watcher behavior

### Required CI matrix

At minimum, CI should distinguish:

1. static/shell syntax validation
2. Cockpit unit/behavior tests
3. Ubuntu/Linux integration
4. macOS integration
5. Omarchy plugin manifest + QML validation in an Omarchy-capable environment
6. Termius protocol/touch regression tests using deterministic fixtures
7. source-branding audit ensuring canonical implementation identifiers are `cockpit`
8. secret scan/profile publication validation

Hardware/UI smoke tests that cannot be faithfully virtualized should be explicitly documented as release checks rather than silently omitted.

## Rebrand completion criteria

The source rebrand is not complete merely because the repository and visible status bar say Cockpit.

Completion requires a repository-wide audit of executable source and generated/configured runtime paths so that:

- canonical tmux session is `cockpit`
- canonical config/state root is `~/.config/cockpit`
- canonical commands/helpers are `cockpit*`
- environment variables use the Cockpit namespace except provider-owned variables such as Codex CLI overrides
- installer/migration/generated config writes Cockpit names
- plugin/runtime metadata uses Cockpit names
- tests assert Cockpit names
- no new code path creates or depends on a `codex-cockpit` namespace
- any unavoidable historical reference is isolated to documentation, changelog, or migration fixture and is not authoritative runtime behavior

Add an automated branding audit so legacy implementation identifiers cannot drift back into source.

## Implementation order

1. Establish this RFC and acceptance matrix.
2. Complete canonical source rebrand and branding audit.
3. Extract platform adapters while preserving existing Foot + Termius behavior.
4. Establish Cockpit profile schema and branding contract.
5. Establish capability/auth broker and secret-free profile packaging rules.
6. Generalize Cockpit plugin API, including nested-pane applications and dependency declarations.
7. Add Pi as a normal provider adapter.
8. Build and validate the Omarchy/Quattro plugin integration against the official standard.
9. Add Ubuntu and macOS CI/integration coverage.
10. Build the Sai Harness profile/distribution, then Sai Intercom, device/agent graph, workflows, and automations on top of those contracts.

## Definition of done

This RFC is fulfilled when:

- Cockpit is canonically named throughout authoritative source/runtime behavior.
- Existing Cockpit features pass the zero-regression matrix.
- Termius touch behavior is preserved and continuously validated.
- Omarchy/Foot remains the native reference experience.
- Cockpit has a validated Omarchy plugin integration conforming to the current official standard.
- Cockpit core runs and is tested on Ubuntu and macOS without requiring Omarchy.
- Cockpit plugins can host declared external open-source terminal applications in managed nested panes.
- Profiles are declarative, brandable, capability-addressed, and secret-free.
- GitHub-sensitive flows bind to the local authenticated identity rather than publishing credentials.
- Pi is available through the generic provider contract.
- Sai Harness can be represented as a first-party Cockpit profile/distribution rather than a permanent fork of core runtime.
- Sai Intercom and orchestration can address agents, devices, sessions, workflows, and automations across machines without collapsing those concepts into one tmux process.
