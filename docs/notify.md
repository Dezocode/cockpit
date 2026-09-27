# Cockpit notifications

Outbound alerts use a single sender: `bin/cockpit-notify`, invoked as `cockpit notify` or `POST /api/notify` on the Hostinger web API.

## Sinks

1. **Telegram** — `hermes send --to telegram -q "<text>"` when the Hermes CLI is installed, otherwise the Bot API with server-side credentials.
2. **ntfy** — fallback topic publish (`COCKPIT_NTFY_TOPIC`, optional bearer).
3. **Desktop** — `notify-send` (Linux) or `osascript` (macOS) when a GUI session exists.

## Hostinger provisioning

Tokens never belong in git, the browser, or `VITE_*` variables.

On the subscription host:

```bash
sudo install -d -m 0750 -o root -g cockpit /etc/cockpit
sudoedit /etc/cockpit/notify.env
```

Example contents (fill real values at ship time):

```
COCKPIT_TELEGRAM_BOT_TOKEN=
COCKPIT_TELEGRAM_CHAT_ID=
COCKPIT_NOTIFY_KEY=
# optional ntfy fallback
COCKPIT_NTFY_TOPIC=
```

`packaging/systemd/cockpit-web.service` loads this file via `EnvironmentFile=-/etc/cockpit/notify.env`. Restart after edits:

```bash
sudo systemctl restart cockpit-web
```

## Verify

```bash
cockpit notify --check --json
COCKPIT_NOTIFY_DRY_RUN=1 cockpit notify "Cockpit v2.3.0 GTM done"
```

Release shipper: when `--check` reports `"telegram":"ready"`, run:

```bash
cockpit notify "Cockpit v2.3.0 GTM done"
```

## Remote clients

Laptops and cloud agents without the bot token can set `COCKPIT_NOTIFY_URL` (e.g. `https://your-host/api/notify`) and `COCKPIT_NOTIFY_KEY`, then `cockpit notify --via api "message"`.

## Rotation

Update `/etc/cockpit/notify.env`, restart `cockpit-web`, and re-run `cockpit notify --check`. Receipts in `~/.local/state/cockpit/notify.jsonl` never store secrets.
