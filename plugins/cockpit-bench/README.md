# cockpit.bench

`cockpit.bench` is the read-only BENCH page. It follows the resident terminal
page family used by FILES and provides a small ghui-style Miller drill; it
does not launch VisiData.

The visual contract is recorded in `aspects/bench-ghui-approved-style-t533u.md`.

## Source contract

The surface reads only the Proctor mirror. Tests may set
`COCKPIT_PROCTOR_HOME`; otherwise the source is
`$COCKPIT_INTERCOM_HOME/proctor` or `~/intercom/proctor`.

The mirror must contain `db/runs.sqlite` and `MODELS_INDEX.csv`. The SQLite
receipt has `models`, `runs`, and `run_links` tables. Model rows expose the
stored `agent_class` badge. Run rows come from `runs`; backlink chips come from
`run_links` and resolve to existing `runs.run_id` values. A missing or
incomplete mirror, including a dangling backlink, renders `ABSENT` and no
rows. Box truth and its spreadsheets remain Proctor-owned inputs and are not
opened by this surface.

## Drill

- L1 models → Enter opens the selected model's runs.
- L2 runs → Enter opens the selected run and its backlinks.
- L3 run + backlinks → Enter on a backlink follows its `to_run_id` (including
  `sol_session_ref` links); Esc restores the prior run and then pops levels.

The page never invents score or run data and never writes the mirror. Proctor
is the sole writer; normal Cockpit wake/PID bookkeeping is separate.

BENCH is a named top-level tmux window with pane role `bench`, is routed by
`cockpit-main`, `cockpit-touch`, `cockpit-adapt`, `cockpit-reload-views`, and
`cockpit-wake`, and is not a toolbar chip.
