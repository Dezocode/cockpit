# H0 health contract — bootstrap vs full API

Authority: t847u residuals t72u · Hostinger install root `/opt/cockpit`

## Two health endpoints (do not conflate)

| Source | Path | Role | PASS for done-line? |
|--------|------|------|---------------------|
| **Full API** | `app/dist-server/index.js` | systemd `ExecStart`; full `/api/*` + WebSocket | **Yes** — H0 + t384u |
| **Bootstrap** | `packaging/health-server.js` | Optional pre-install probe; GET `/api/health` only | **No** — residual probe only |

## Full API health (`app/dist-server/index.js`)

Started by:

- systemd: `packaging/systemd/cockpit-web.service`
- local: `./scripts/start-dist-server.sh`
- bench: `COCKPIT_HOSTINGER=1 node app/dist-server/index.js`

Required response fields:

```json
{
  "status": "green",
  "product": "cockpit",
  "source": "app/dist-server/index.js",
  "checks": {
    "tui": "ok",
    "fixtures": "ok",
    "api_server": "ok",
    "web_build": "ok",
    "hostinger": "configured"
  }
}
```

Probe:

```bash
./scripts/hostinger-health.sh
# or
curl -s http://127.0.0.1:8787/api/health | jq .
```

On Hostinger after install, `source` **must** be `app/dist-server/index.js`.  
Claims that bootstrap `packaging/health-server.js` satisfies the full API contract are **residual** and must not appear in PASS language.

## Bootstrap health (`packaging/health-server.js`)

Optional artifact check before `dist-server` is built:

```bash
node packaging/health-server.js
```

Response includes `"source": "packaging/health-server.js"`.  
Does **not** serve `/api/agents`, SPA, or WebSocket.  
**Not** a substitute for dist-server PASS.

## Hostinger install path

`scripts/install-hostinger.sh`:

1. `pnpm build` + `tsc -p tsconfig.server.json`
2. rsync → `/opt/cockpit`
3. `pnpm install --prod` in `/opt/cockpit/app` (node deps for dist-server; no Saul)
4. systemd starts `node /opt/cockpit/app/dist-server/index.js`

## Evidence paths

| Artifact | Path |
|----------|------|
| Health JSON | `bench/cockpit/screenshots/t384u/hostinger-health.json` |
| Live SPA shots | `bench/cockpit/screenshots/t384u/*.png` |
| Manifest | `bench/cockpit/screenshots/t384u/MANIFEST.json` |

Capture: `./bench/cockpit/capture-screenshots.sh` (vite preview + dist-server).
