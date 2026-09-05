# Cockpit BENCH — Proctor ghui contract

BENCH is a named, read-only Cockpit page for drilling benchmark records. It is
implemented as a resident terminal UI in the same page family as FILES. It
uses the Proctor mirror's SQLite receipt through read-only queries and does
not invoke VisiData, access Box truth or its spreadsheets, attach to a remote
session, or write scores.

## Source and fail-closed rules

The surface reads only `~/intercom/proctor` (or
`COCKPIT_PROCTOR_HOME` for an isolated test). A valid mirror has
`db/runs.sqlite`, `MODELS_INDEX.csv`, and SQLite tables `models`, `runs`, and
`run_links`. Model `agent_class` values are displayed as badges; backlinks
must resolve to existing run ids. Any missing or invalid source leaves the
whole surface at `ABSENT` with no rows.

## Levels

| Level | Content | Enter | Esc |
|---|---|---|---|
| L1 | models with `agent_class` badge | open model runs | close page |
| L2 | selected model's runs | open run detail | L1 |
| L3 | run metadata and backlinks | follow selected `to_run_id` | pop jump history / L2 |

The Proctor process is the sole writer. BENCH only reads the mirror and writes
its normal Cockpit runtime wake/PID bookkeeping.

## Named-page wiring

| Item | Value |
|---|---|
| Window | `BENCH` |
| Pane role | `@cockpit_role bench` |
| Plugin | `cockpit.bench` |
| Bootstrap | `cockpit-main` → `new-window -n BENCH` → `exec cockpit-bench` |
| Touch | `cockpit-touch bench\|BENCH` |
| Adapt | `bench:BENCH` and `bench:9` |
| Wake | `cockpit-wake … BENCH` |
| Toolbar | unchanged six chips |
