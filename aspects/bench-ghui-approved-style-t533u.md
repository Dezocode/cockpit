# BENCH ghui approved style (t533u)

BENCH uses the same resident terminal-page grammar as FILES: three Miller
columns remain visible while focus moves between them.

| Column | Content |
|---|---|
| 1 | `Models` with the Proctor `agent_class` badge |
| 2 | `Runs — <model>` |
| 3 | `Run + backlinks`, with yellow backlink chips |

Top-left chrome is:
`cockpit · MEMORY  COMPUTERS  MODELS  BENCH  FILES  PRS`

Top-right chrome is:
`BENCH  ghui  read-only`

The footer identifies the drill and source:
`t524u ghui  ·  Esc=pop  Enter=drill/backlink  ·  data: ~/intercom/proctor/  ·  writer: Proctor`

Keyboard behavior:

- Up/Down or `j`/`k` moves within the focused column.
- Left/Right or Tab moves focus between columns.
- Enter drills from model to runs to detail and follows a selected backlink's
  `to_run_id`.
- Esc restores the backlink jump stack, then pops drill focus.
- `q` exits the temporary drill; the named BENCH pane remains the page.

The surface remains read-only and fail-closed. It never turns the benchmark
source into a toolbar chip or a nested pane.
