# Cockpit 2.1.3

Done-line release — CI-driven GitHub Release via `release-cockpit2.yml`.

## Release workflow

Tag push `v2.*` → build bundle → capability matrix → **GET /api/health proof** → publish Release assets.

## Canon Hostinger (deploy separately)

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.3/scripts/hostinger-grok-build.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.3/deploy/hostinger-grok-build-install.sh | sudo bash
```

Install root: **`/opt/cockpit`** — Saul `/root/.grok` / `saul-go` untouched.

## Health (CI-proven)

```bash
curl -s http://127.0.0.1:8787/api/health | jq .
```

Green contract documented in [deploy/README.md](deploy/README.md).

## Assets

| File | Contents |
|------|----------|
| `cockpit-2.1.3-linux-x64.tar.gz` | Full bundle + packaging + deploy + scripts |
| `cockpit-2.1.3-web.tar.gz` | Web + API + Hostinger packaging |
