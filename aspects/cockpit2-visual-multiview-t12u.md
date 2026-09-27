# Aspect: cockpit2-visual-multiview-t12u

**Card:** `cursor-cockpit2-visual-multiview-t12u`  
**Gospel:** `bench/cursor/reports/t10u-cockpit-visual-multiview-gospel.md`

## Style contract (STYLE ONLY from style-ref)

Source: `proofs/t12u/style-ref-fieldset.png` — fieldset terminal console. **Never copy LMS/course content.**

| Element | Rule |
|---------|------|
| Canvas | Near-black (`--cockpit-bg`) |
| Fieldset border | 1px cyan (`--cockpit-border`) |
| Title-in-border | `FieldsetPanel` legend over top border |
| Active / nav emphasis | Magenta (`--cockpit-active`) |
| Body text | Light gray (`--cockpit-text`) |
| Typography | Monospace only |

## Visual gap table (baseline → 2.2)

| Gap | v2.1.4 ugly baseline | 2.2 target | must_absent proof |
|-----|----------------------|------------|-------------------|
| Equal-width strips | 9 equal dockview columns | Staging drag canvas + resizable panels | `staging-3-panels.png` ≠ equal strips |
| Yellow-pill primary | Idle bar chips yellow-filled | Cyan outline idle; magenta active | AgentBar tone audit |
| Rounded cyan splash pills | Solid `bg-cyan-*` buttons | Fieldset auth + border buttons | `login-splash.png` fieldset |
| Hardcoded panel hex | `#0b0f14`, `text-cyan-300` | `tokens.css` + modules only | grep panels/*.module.css |
| LMS copy | N/A (deny) | No course/assignment strings | grep deny terms |

## Routes

- `/splash` — pre-auth device-flow
- `/splash/staging` — post-auth multiview (primary 2.2 surface)
- `/workspace` — legacy parity (fieldset-wrapped, zero capability loss)

## Persistence keys

- `cockpit.theme`
- `cockpit.layout.v3`
