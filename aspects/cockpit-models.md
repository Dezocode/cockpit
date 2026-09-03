# Cockpit COMPUTERS / MODELS — compiled entry points

Status: Goal 2 slice (read-only roster, receipt-fed, fail-closed)

## Plugin

```ini
id=cockpit.computers
type=cockpit
entrypoint=computers
```

## Source contract (fail-closed)

Receipt order:

1. `$COCKPIT_INTERCOM_HOME/computers/receipt.tsv` (default `~/intercom/computers/receipt.tsv`)
2. `$COCKPIT_PROJECT/computers/receipt.tsv` (cwd-relative project fallback)

If neither path exists or the receipt is unreadable, COMPUTERS shows an explicit
error. Cockpit does not attach to remote hosts, spawn cross-device daemons,
scrape workspace aspects, or synthesize roster rows.

## Receipt format

Tab-separated values with a header row:

```text
device_id	display_name	kind	status	models
local	This host	local	online	codex
```

- `models` is a comma-separated catalog for the device (MODELS subview input).
- Rows are read-only; no control plane or live sync beyond filesystem events.

## CLI entry points

| Command | Output |
|---------|--------|
| `computers path` | Resolved receipt path (stdout) |
| `computers check` | `status=ok`, `device_count=N` or non-zero exit + message |
| `computers roster` | Body lines (no header) for the default roster subview |
| `computers models` | Aggregated model lines for the `m` subview inside COMPUTERS |

Also reachable as `cockpit-plugin run cockpit.computers …` and `cockpit computers …`.

## Session wiring

| Item | Value |
|------|-------|
| Window name | `COMPUTERS` |
| Window index | `8` (after `MEMORY` at `7`) |
| Pane role | `@cockpit_role computers` |
| Bootstrap | `cockpit-main` → `new-window -n COMPUTERS` → `exec cockpit-computers` |
| Touch route | `cockpit-touch computers\|COMPUTERS` with MEMORY-style unnesting |
| Adapt | `computers:COMPUTERS` in `layout_tabs`; `computers:8` in tab order |
| Wake | `cockpit-wake … COMPUTERS` |
| CPR | `preserved=…,MEMORY,COMPUTERS`; `--refresh-derived` may respawn COMPUTERS |

## Subviews (inside COMPUTERS only)

| Key | Subview | Notes |
|-----|---------|-------|
| (default) | roster | Read-only device table from receipt |
| `m` | MODELS | Read-only model catalog aggregated from receipt `models` columns |

MODELS is **not** a ninth tmux window. Do not add `new-window -n MODELS`.

## Non-goals (this slice)

- No tmux attach to remote sessions
- No live cross-device daemon
- No Funnel / tailnet Ollama integration
- No cross-device control or command dispatch
- Do not bind prefix `e` (reserved for runtime provider popup)
- Lower Agent toolbar stays six chips (PRS · AGENT · 2:FILES · MEMORY · MODEL · RESTART)
