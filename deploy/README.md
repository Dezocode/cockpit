# Hostinger fresh install one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/main/install.sh | COCKPIT_INSTALL_HOSTINGER=1 COCKPIT_INSTALL_WEB_BUILD=1 bash
```

After install:

```bash
certbot --nginx -d cockpit.example.com
systemctl start cockpit-web
curl -sf https://cockpit.example.com/api/health | jq .
```

Expected health: `"status": "green"` with `checks.hostinger: "configured"`.
