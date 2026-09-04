# BENCH ghui approved style (t533u)

Status: **HARD STYLE LOCK** — live renderer must match exactly.

Reference: `proofs/approved-style/bench-ghui-approved-t533u.png`

## Layout

Three **Miller columns** visible simultaneously (not a stack drill, not VisiData):

| Column | Header | Content |
|--------|--------|---------|
| 1 | `Models` | Model id + site badge (`frontier`, `local`, `ABSENT`) |
| 2 | `Runs — <model_id>` | Run id (2 lines: id + status) |
| 3 | `Run + backlinks` | Selected run id + yellow backlink chips |

Vertical column separators between panes.

## Chrome

**Top left:** `cockpit · MEMORY  COMPUTERS  MODELS  BENCH  FILES  PRS`

**Top right:** `BENCH  ghui  read-only`

**Footer:** `t524u ghui  ·  Esc=pop  Enter=drill/backlink  ·  data: ~/intercom/proctor/  ·  writer: Proctor`

(`data:` path reflects resolved receipt root, `~`-shortened when under `$HOME`.)

## Selection & color

- Cyan `>` cursor on the active row in the focused column
- Model site badges: `frontier` / `local` / `ABSENT` (muted when ABSENT)
- Backlinks section header: yellow `Backlinks (Enter → jump)`
- Backlink targets: yellow-bordered chips with `link_kind` label + truncated run id

## Keys (t524u grammar)

| Key | Action |
|-----|--------|
| ↑↓ | Move within focused column |
| ←→ / Tab | Focus adjacent column |
| Enter | Drill selection / jump backlink peer run |
| Esc | Pop backlink jump stack |
| q | Quit drill |

## Non-goals

- Not a single-column stack replacing columns
- Not VisiData / sc-im / Excel product UI
- No invented scores; Proctor sole writer
