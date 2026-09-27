# Cockpit Laya plugin

Optional local routing via [Laya](https://pypi.org/project/laya/). Install with `cockpit laya install`, start with `cockpit laya start`, then `cockpit route --launch "your task"`.

Privacy: only a SHA-256 of task text is stored in `route.jsonl`; traffic stays on `127.0.0.1`. Set `COCKPIT_LAYA=0` or `cockpit laya disable` to turn routing off with zero launch impact.
