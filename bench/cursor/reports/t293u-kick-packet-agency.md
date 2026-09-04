# t293u kick packet — BENCH bar agency

**Card:** `cursor-bench-bar-agency-t293u`  
**Branch:** `cursor/bench-ghui-7ed3`  
**PR:** #4 (draft only)

## Goal

Close IMPROVE schemas vs approved bar PNG (`bench-ghui-approved-t533u.png`).
Keep yellow chip fill + ASCII-absent outlook from t649u/t652u. Ship full
Miller agency (top chrome, badges, nesting, L3 parent header, multi-chip,
density, touch, resize).

## Prior inspect (t660u / t649u)

- t610u: yellow fill PASS
- t649u: subtract ASCII chip drawer PASS
- t652u: final outlook = add agency AND subtract legacy
- Live 232336: chips closed; everything else still NEAR vs bar

## Implementation surface

- `stage/nvim/lua/config/cockpit-bench.lua`
- `tests/test-bench-agency-style.sh`
- `tests/test-bench.sh` nested fixture rows
- `tests/test-bench-ghui-style.sh` nesting guard

## Deny kick

`sol-v1.7.1`, `local/*`, `Qwen`

## Evidence required post-land

Live CPR screenshot on dezohost ≠ approved PNG ≠ 232336 capture.
