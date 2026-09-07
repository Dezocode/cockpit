# Cockpit 2.1.2

Hostinger kick **LOCKED** — envelope hardening on grok-build lane + stricter health contract when `COCKPIT_HOSTINGER=1`.

## Canon Hostinger one-liners

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.2/scripts/hostinger-grok-build.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.2/scripts/install-hostinger.sh | sudo bash
```

Install root: **`/opt/cockpit`** — Saul `/root/.grok` and `saul-go` **untouched**.

## Lock checklist (t72u)

| # | Artifact | Status |
|---|----------|--------|
| 1 | `install.sh` + `scripts/install-hostinger.sh` → `/opt/cockpit` | ✓ |
| 2 | `packaging/systemd/cockpit-web.service` + heal | ✓ |
| 3 | `packaging/nginx/cockpit.conf` | ✓ |
| 4 | `GET /api/health` green contract | ✓ |
| 5 | `scripts/hostinger-grok-build.sh` — subscription only, DENY Qwen/sol-v1.7.1, Funnel OFF | ✓ |
| 6 | GitHub Release tarballs | ✓ |

## Verification

```bash
./bench/cockpit/capability-matrix.sh   # 56/56
./bench/cockpit/hostinger-h0-verify.sh # 7/7
./bench/cockpit/surface-matrix.sh      # 14/14
./bench/cockpit/tui-harness.sh         # 6/6
```
