# BENCH bar agency — next schemas (t293u)

Agency pass on the approved Miller bar: full L1/L2/L3 drill polish, not
chips-only.

## Approved reference

`/workspace/proofs/approved-style/bench-ghui-approved-t533u.png`

## Keep (prior turns)

| Item | Source |
|---|---|
| Yellow chip fill (`PUNCH_YELLOW_CHIP` / `CockpitBenchChipFill`) | t610u |
| No ASCII `+---+` / pipe chip borders | t649u/t652u |
| Cyan selection, gold labels, single footer, 3-column layout | t533u |
| FILES surface untouched | t533u |

## Add / improve

| Schema | Target |
|---|---|
| `ui/bench-bar-top-chrome` | Cyan `cockpit` brand + product nav weight; tmux mode drops duplicate `BENCH` right chrome |
| `ui/bench-bar-models-badges` | Cyan `>` on selected model; dim `frontier`/`local`/`ABSENT` badges |
| `ui/bench-bar-runs-nesting` | Parent selectable; `::` children indented; no flat child-only soup |
| `ui/bench-bar-l3-header` | Gold `run_id (selected)` shows parent UUID; dim tag soup |
| `ui/bench-bar-yellow-backlink-chips` | N filled chips for N backlinks; fuller `parent::suffix` ids |
| `ui/bench-bar-visual-density` | Flatter L3 spacing; watermark must not fight labels |
| `ui/bench-bar-touch-and-keyboard` | Mouse + j/k/Tab/Enter/Esc unchanged |
| `ui/bench-bar-resize-no-obfuscate` | `VimResized` re-layout preserves nesting + chips |

## Subtract

- Chips-only agency (must ship L1/L2/L3 together)
- Flat `uuid::child` L2 when parent grouping exists
- Double-chrome dominance (nvim tabline vs tmux tabs)
- Single-chip L3 when ≥2 backlinks exist

## Tests

- `tests/test-bench-ghui-style.sh` — t533u/t649u baseline
- `tests/test-bench-agency-style.sh` — t293u agency grep contract
- `tests/test-bench.sh` — nested runs + multi-backlink fixture rows
