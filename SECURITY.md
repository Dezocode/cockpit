# Security

## Browser-exposed keys (C6 / C10)

Only keys marked `clientExposed` in the KEY_SETUP_KEYS registry may reach the browser, and only via a runtime config endpoint with referrer restrictions. All other provider keys stay server-side in a 0600 store (`~/.config/cockpit/keys.env` or `pinokio/ENVIRONMENT`). The SETUP → KEYS panel never displays a value — only presence (`set ✓`). Proxied / Hostinger requests to `/api/setup/*` are refused; use `cockpit keys` over SSH there.
