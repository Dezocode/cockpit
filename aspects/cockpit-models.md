# Cockpit COMPUTERS / MODELS — compiled entry points

Status: Goal 2 slice (read-only roster, receipt-fed, fail-closed)

## Plugin

```ini
id=cockpit.computers
type=cockpit
entrypoint=computers
```

## Source contract (fail-closed)

Receipt order (JSON node receipts are the live contract):

1. `$COCKPIT_INTERCOM_HOME/models/*.json` (default `~/intercom/models/*.json`)
   — one logical node per file
2. `$COCKPIT_INTERCOM_HOME/computers/receipt.tsv` (legacy compatibility)
3. `$COCKPIT_PROJECT/models/*.json` (cwd-relative project fallback)
4. `$COCKPIT_PROJECT/computers/receipt.tsv` (cwd-relative project fallback)

Each readable `models/<node>.json` is validated independently. Valid receipts
each produce one roster row; invalid files are omitted with a visible
fail-closed message and do not invent rows. If every JSON file in the active
models directory is invalid or unreadable, COMPUTERS exits closed and does not
fall through to TSV. Cockpit does not attach to remote hosts, spawn
cross-device daemons, scrape workspace aspects, dispatch commands, or synthesize
roster rows.

## Legacy TSV format

Tab-separated values with a header row:

```text
device_id	display_name	kind	status	models
local	This host	local	online	codex
```

- `models` is a comma-separated catalog for the device (MODELS subview input).
- Rows are read-only; no control plane or live sync beyond filesystem events.

## Node JSON format

Each node-local `models/<node>.json` receipt is schema 1:

```json
{
  "schema": 1,
  "node": "deck",
  "runtimes": [
    {
      "runtime": "hermes+llama.cpp",
      "endpoint": "127.0.0.1:8080",
      "reachable": true,
      "gateway_state": "running",
      "models": [{"id": "local/Qwen3.5-4B", "state": "served"}]
    }
  ],
  "notes": ["tailscale_hostname=dezodeck"]
}
```

`node` is the logical id (one roster row per receipt file). The first non-empty
`tailscale_hostname=` note supplies the device/host column when present; multiple
logical nodes may share one Tailscale hostname. Runtime/model rows are read-only
projections; no Surface-to-node SSH or command bus is opened by COMPUTERS.

## CLI entry points

| Command | Output |
|---------|--------|
| `computers path` | Resolved receipt path(s) (stdout; one per valid JSON node file) |
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
