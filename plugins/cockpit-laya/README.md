# Cockpit Laya plugin (optional)

Local routing with [Laya](https://pypi.org/project/laya/): before a launch, a
small local model picks the tier (cheap/standard/top) and the runtime for a task.

Install and start (Python >= 3.10 with venv; nothing is installed by install.sh or CI):

    cockpit laya install [--device auto|cpu|cuda|mps] [--port N]
    cockpit laya start            # loopback 127.0.0.1 only; turns routing on
    cockpit route --launch "fix the flaky auth test"

The venv lives in `~/.local/share/cockpit/laya/venv`; the first start downloads
the model (~0.8-1.7 GB) into the Hugging Face cache.

`cockpit laya start` sets only upstream's documented variables (LAYA_HOST=127.0.0.1,
LAYA_PORT, LAYA_DEVICE, LAYA_PRELOAD, LAYA_MODELS, LAYA_THREADS, LAYA_API_KEY) and
drops any other inherited LAYA_*. Routing defaults off (`enabled=0`, or no laya.conf).

Privacy: the server binds 127.0.0.1 only and needs a bearer key kept in
`~/.local/state/cockpit/laya/api.key` (0600, never printed, never on argv).
Receipts in `~/.local/state/cockpit/route.jsonl` store the task's sha256, never its text.

Latency: `timeout_ms` defaults to 400. On CPU the four route questions took
~550 ms warm (laya 0.3.20, 8 vCPU); set `timeout_ms=1000` or
`COCKPIT_LAYA_TIMEOUT_MS=1000` there, or routing silently times out to defaults.

Turn it off: `cockpit laya disable` or `COCKPIT_LAYA=0`. Absent, disabled, down
or slow Laya is a silent no-op: launches use the usual runtime and model.

MCP: `cockpit laya mcp register --client cursor|codex|hermes|all [--dry-run]`.
