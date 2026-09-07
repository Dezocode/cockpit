# Cockpit 2.2 Visual Style Guide

Terminal console aesthetic — fieldset panels, monospace, token-driven chrome. **Do not copy LMS/course content.**

## Tokens (`app/src/styles/tokens.css`)

All panel CSS modules MUST reference CSS variables only:

| Token | Role |
|-------|------|
| `--cockpit-bg` | Page background (near-black) |
| `--cockpit-panel` | Fieldset fill |
| `--cockpit-border` | Fieldset 1px border (cyan family) |
| `--cockpit-chrome` | Labels, titles, chrome |
| `--cockpit-active` | Active tab / selection (magenta family) |
| `--cockpit-text` | Body text |
| `--cockpit-muted` | Secondary text |
| `--cockpit-focus-ring` | `:focus-visible` ring |

**DENY:** hardcoded accent hex in `app/src/panels/*.module.css` or panel components.

## Fieldset panels

```tsx
<FieldsetPanel title="AGENTS">{content}</FieldsetPanel>
```

- 1px `var(--cockpit-border)` border
- Title sits in border (`legend` pattern)
- Monospace via `--cockpit-font`

## Themes (≥3)

| ID | Description |
|----|-------------|
| `fieldset-dark` | Default near-black + cyan + magenta active |
| `ghui-cyan` | t533u chip palette extended |
| `high-contrast` | Accessibility |

Persist: `localStorage` key `cockpit.theme`. Switcher in SETUP + staging toolbar.

## Multiview staging

- Route: `/splash/staging` (post-auth)
- Drag palette: **Agents**, **Computers**, **Files**
- Layout persist: `cockpit.layout.v3`
- Charts: ResizeObserver + uPlot in Graph panel

## Unchanged gospel (v2.1.4 baseline)

- 6-chip AGENT bar (no 7th)
- MODELS = `m` inside COMPUTERS
- Foot size-owning · Funnel OFF · Serve OFF
- GitHub device-flow splash · PTY · Origin ≠ bus
