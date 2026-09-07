# Cockpit 2 audit proposal (bench/cockpit)

## Scope

Audit harness for parallel TUI + GUI upgrade without Surface/dezohost regression.

## Checks

1. **TUI session integrity** — `cockpit-main` creates AGENT|FILES|DIFF|SETUP|MAP|PRS windows; CPR nondestructive.
2. **Foot size-owning** — dezohost product socket unchanged; GUI does not kill TUI socket.
3. **Origin ≠ intercom bus** — intercom plugin messages never routed through Origin HTTP.
4. **cockpit.memory / cockpit.intercom fail-closed** — API returns failClosed when plugin absent.
5. **BENCH read-only** — Proctor writes only; bench page is RO in GUI.
6. **Multi-account isolation** — Zustand `accountId` + separate gh auth per machine.
7. **PTY lifecycle** — spawn/write/resize/kill on both portable-pty (Tauri) and node-pty ws (web).
8. **Tailnet offline ≤3s** — COMPUTERS page latency threshold 3000ms.

## Run

```bash
./bench/cockpit/capability-matrix.sh
./bench/cockpit/doctor.sh
./bin/cockpit-audit
```

## Evidence

Store screenshot artifacts under `bench/cockpit/screenshots/t384u/` per gospel done-line.
