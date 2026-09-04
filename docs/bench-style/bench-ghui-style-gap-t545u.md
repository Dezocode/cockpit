# BENCH ghui style gap — live vs approved (t545u)

**Dezocode:** "The style canon showed is close but lacks the polish of this bar colors and highlighting boxes etc"

## Approved bar (pixel truth)
`/workspace/proofs/approved-style/bench-ghui-approved-t533u.png`

## Live (close, under-polished)
`/workspace/bench-ghui-t384u-live.png`

## Still lacking (style only — not layout)
| Gap | Approved | Live |
|---|---|---|
| Selection color | Bright cyan `>` + cyan selected text | Dimmer / less punchy cyan |
| Backlink chips | Yellow/gold **boxed** cards (border + slight fill elevation) with yellow `link_kind` + gray id | Missing — ABSENT empty; when filled must be yellow boxes not plain lines |
| Detail labels | Gold `run_id (selected)` + gold `Backlinks (Enter → jump)` | Flat/dim; no gold hierarchy |
| Column headers | Clean weight vs body | Weaker hierarchy |
| Separators | Thin continuous rules matching mock | ASCII `-`/`|` dashed feel — OK for ncurses safety but read as less polished; prefer continuous if Omarchy allows |
| Right chrome | `BENCH ghui read-only` cyan/teal accent | Present but quieter |
| Status badges | Aligned dim `frontier`/`local`/`ABSENT` | Present |
| Content density | Populated run + two yellow backlink boxes | Stuck ABSENT / first-model — polish can’t be judged until drill fills col 2–3 |

## Non-goals
Do not change 3-miller structure. Do not go VisiData. t213u resize/touch/perf still apply.

## Canon
Soft-steer PR #4: match approved colors + yellow highlighting boxes. t384u done-line needs filled drill AND this polish.
