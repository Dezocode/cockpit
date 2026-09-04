# Cockpit BENCH — compiled entry points (t524u)

Status: Draft slice (read-only ghui drill, Proctor-fed, fail-closed)

## Plugin

```ini
id=cockpit.bench
type=cockpit
entrypoint=bench
```

## ghui interaction (FILES-grammar)

| Level | View | Keys |
|-------|------|------|
| L1 | Models index | Enter → L2 for selected model |
| L2 | Runs for model | Enter → L3 for selected run |
| L3 | Run detail + backlinks | Enter on backlink → jump peer run at L3 |
| any | Stack | Esc pops one level; q quits drill |

- Read-only. No Proctor pane keys. No VisiData/sc-im/Excel product path.
- `frontier` hosts show a `≠local` badge; local hosts show `local`.
- Missing scores render as `ABSENT` (fail-closed). Cockpit never invents scores.
- Proctor is the sole writer of bench receipts.

## Source contract (fail-closed)

Receipt order:

1. `$COCKPIT_INTERCOM_HOME/proctor/` (default `~/intercom/proctor/`) when
   `db/runs.sqlite` exists — preferred mirror on dezohost
2. `$COCKPIT_BENCH_HOME` or `/workspace/bench/` (box truth) when intercom mirror absent

Required paths under the resolved root:

| Path | Role |
|------|------|
| `db/runs.sqlite` | `models`, `runs`, `run_links` tables (required) |
| `MODELS_INDEX.csv` | Model catalog index (required) |
| `CROSSREF_LINKS.csv` | Cross-run links (optional; backlinks may be ABSENT) |
| `models/*.xlsx` | Per-model score workbooks (optional; not opened as product UI) |

### ABSENT paths (documented, never invented)

| Condition | UI |
|-----------|-----|
| No intercom mirror and no box `runs.sqlite` | BENCH pane: `BENCH unavailable` |
| `runs.sqlite` unreadable or schema incomplete | fail-closed exit / ABSENT message |
| `MODELS_INDEX.csv` missing | fail-closed |
| Model has zero runs | L2: `ABSENT: no runs for <model>` |
| Run row missing | L3: `ABSENT: run <id>` |
| Run has no backlinks | L3: `ABSENT: no backlinks` |
| `score_status` null/empty | displayed as `ABSENT` |

Cockpit does not scrape Sol campaign paths, write scores, or open xlsx in VisiData.

## CLI entry points

| Command | Output |
|---------|--------|
| `bench path` | Resolved root, db, csv paths |
| `bench check` | `status=ok`, counts, or non-zero + message |
| `bench models` | `model_id<TAB>display_name` lines |
| `bench runs MODEL_ID` | run rows for model |
| `bench show-run RUN_ID` | run detail + `backlink<TAB>…` lines |

Also: `cockpit-plugin run cockpit.bench …`, `cockpit bench …`.

## Session wiring

| Item | Value |
|------|-------|
| Window name | `BENCH` |
| Window index | `9` (after `COMPUTERS` at `8`) |
| Pane role | `@cockpit_role bench` |
| Bootstrap | `cockpit-main` → `new-window -n BENCH` → `exec cockpit-bench` |
| Touch route | `cockpit-touch bench\|BENCH` with MEMORY-style unnesting |
| Adapt | `bench:BENCH` in `layout_tabs`; `bench:9` in tab order |
| Wake | `cockpit-wake … BENCH` |
| CPR | `preserved=…,BENCH`; `--refresh-derived` may respawn BENCH |

## Agent toolbar

Lower Agent toolbar stays **six chips** (PRS · AGENT · 2:FILES · MEMORY · MODEL · RESTART).
BENCH is a named page only — no seventh toolbar chip.

## Non-goals (this slice)

- No score writing (Proctor only)
- No VisiData / sc-im / Excel product integration
- No Funnel / Surface→Deck Sol SSH
- No Proctor control-plane keys in the pane
- Do not merge or ship from this draft branch
