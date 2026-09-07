# Cockpit 2.1.4

t847u Canon draft alignment — `packaging/health-server.js` + `tmp/t847u/README.md` manifest.

## Gospel paths (unchanged)

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.4/scripts/hostinger-grok-build.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.4/deploy/hostinger-grok-build-install.sh | sudo bash
```

Install root **`/opt/cockpit`** — Saul untouched.

## t847u alignment

See `tmp/t847u/README.md` for Canon draft ↔ in-repo path map.

## Health

- Full API: `app/server/index.ts` → `GET /api/health`
- Bootstrap: `packaging/health-server.js`
- Probe: `scripts/hostinger-health.sh`

CI-proven in `.github/workflows/ci.yml` and `release-cockpit2.yml`.
