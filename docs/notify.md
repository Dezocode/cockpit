# Cockpit notifications (`cockpit notify` · `POST /api/notify`)

One sender: `bin/cockpit-notify`. The CLI (`cockpit notify …`) runs it directly; the
web API (`POST /api/notify`) runs it with `execFile` (no shell). The server never talks
to Telegram or ntfy itself, and no browser code ever sees a token.

```
cockpit notify [--title T] [--sink auto|telegram|ntfy|desktop|all] [--require SINK]
               [--priority low|default|high] [--link URL] [--id ID] [--json] [--dry-run]
               [--check] [--via local|api] [--] MESSAGE... | -
```

- MESSAGE words join with single spaces; `-` reads stdin. Control characters except
  newline are stripped. Empty message → exit 2.
- Stdout is exactly one line `notify: delivered=<sink> sinks=<k:v,…> id=<uuid>`, or one
  JSON receipt with `--json` (also on failure). Errors go to stderr, redacted, and name the fix.
- Exit codes: `0` delivered · `2` usage · `3` nothing delivered or `--require` unmet ·
  `4` API auth refused · `5` rate-limited.
- `--dry-run` (or `COCKPIT_NOTIFY_DRY_RUN=1`) validates, writes a receipt with
  `"delivered":"dry-run"` and makes zero network or desktop calls.
- `--id ID` makes retries idempotent: a repeat inside `dedupe_window_s` (default 600 s)
  returns the earlier receipt with `"deduped":true` and sends nothing. Dry runs and failed
  attempts never dedupe, so a retry after a failure really sends.

## Sinks and order

`--sink auto` (default) tries the remote sinks in `order` (`telegram,ntfy` by default)
and stops at the first success — Telegram before ntfy, never both — then shows a
best-effort desktop toast when a GUI session exists. Desktop alone counts as delivery
only when no remote sink is configured.

1. **Telegram** — `hermes send --to telegram -q "<text>"` when the Hermes CLI is on PATH
   (no token needed on this host). Otherwise the Bot API `sendMessage` with
   `COCKPIT_TELEGRAM_BOT_TOKEN` + `COCKPIT_TELEGRAM_CHAT_ID` (plain text, no parse_mode,
   ≤4000 chars). A failing Hermes falls through to the Bot API when that is configured.
2. **ntfy** — `COCKPIT_NTFY_TOPIC` (treat it as a secret: anyone with the topic can
   read it), `COCKPIT_NTFY_SERVER` (default `https://ntfy.sh`), optional `COCKPIT_NTFY_TOKEN`.
   Headers `Title`, `Priority` (2/3/4), `Tags: cockpit`, optional `Click`.
3. **Desktop** — `notify-send -a Cockpit` when `DISPLAY`/`WAYLAND_DISPLAY`/`DBUS_SESSION_BUS_ADDRESS`
   is set, else `osascript` (message passed as argv, never interpolated). Headless → `desktop:skip:headless`.

Every curl call reads its URL (which contains `bot<TOKEN>`), headers and body from a
process-substitution config FD, so `ps` only ever shows `curl … --config /dev/fd/NN`.

## Where secrets live (precedence, first wins)

1. The process environment.
2. `/etc/cockpit/notify.env` (root-owned, `0640`, group `cockpit`). systemd loads it for
   the web API via `EnvironmentFile=-/etc/cockpit/notify.env` in
   `packaging/systemd/cockpit-web.service`; the CLI reads the same file as KEY=VALUE data
   (never sourced, never overriding the environment). `COCKPIT_NOTIFY_ENV_FILE` points the
   CLI at another file (tests use it so they never read the host's file).
3. `cockpit-keys exec --for notify` (C6), when present and nothing above is set.

`~/.config/cockpit/notify.conf` (seeded by `install.sh`) holds non-secrets only:
`order=`, `default_title=`, `dedupe_window_s=`.

Receipts: `${XDG_STATE_HOME:-~/.local/state}/cockpit/notify.jsonl` (mode 0600) —
`ts,id,via,title,message_sha256,preview,sinks,delivered,deduped`. No token, topic or
chat id is ever written; the preview is the first 80 characters, redacted.

## Hostinger provisioning (ship time)

Either install the Hermes CLI on the host (no token needed), or:

```bash
sudo install -d -m 0750 -o root -g cockpit /etc/cockpit
sudoedit /etc/cockpit/notify.env
sudo chown root:cockpit /etc/cockpit/notify.env && sudo chmod 0640 /etc/cockpit/notify.env
sudo systemctl restart cockpit-web
```

```
COCKPIT_TELEGRAM_BOT_TOKEN=
COCKPIT_TELEGRAM_CHAT_ID=
COCKPIT_NOTIFY_KEY=
# optional ntfy fallback
COCKPIT_NTFY_TOPIC=
```

Never commit this file, never put these names in `VITE_*` variables or `app/src`
(`tests/test-notify-lint.sh` fails the build if you do).

## Verify, then send (release shipper)

```bash
cockpit notify --check --json      # {"telegram":"ready|not-configured|invalid","ntfy":…,"desktop":…}
COCKPIT_NOTIFY_DRY_RUN=1 cockpit notify "Cockpit v2.3.0 GTM done"
cockpit notify --id release-v2.3.0 "Cockpit v2.3.0 GTM done"   # → delivered=telegram, exit 0
```

`--check` sends nothing (the Bot API path calls `getMe`). Use `--require telegram` if
anything other than Telegram must count as failure.

## Web API

`POST /api/notify` with JSON `{"message", "title"?, "sink"?, "priority"?, "link"? (https),
"id"?}` → `200` receipt · `400` invalid · `401` · `429` (10/min per principal, token bucket) ·
`502` when no sink delivered (body = the receipt). `GET /api/notify/status` → booleans per sink.

Accepted callers, in order: a GitHub-OAuth session cookie that passes the terminal
allowlist; `Authorization: Bearer $COCKPIT_NOTIFY_KEY` (compared as SHA-256 digests with
`timingSafeEqual`); `COCKPIT_LOCAL_TRUST=1` **and** a loopback socket peer (never a header).
`COCKPIT_HOSTINGER=1` disables local trust outright, and no server unit sets it.

Remote clients (laptops, cloud agents) never hold the bot token: set
`COCKPIT_NOTIFY_URL=https://<host>/api/notify` and `COCKPIT_NOTIFY_KEY`, then
`cockpit notify "message"` (defaults to `--via api` when no local sink is configured).

## Why the browser can never see a token

Tokens exist only in the server process environment and in `bin/cockpit-notify`'s
environment. Responses are the CLI receipt (no secret fields by construction); sink
stderr is never forwarded; nothing under `app/src` references the variable names and
the lint scans the built `app/dist` for them.

## Rotation

Edit `/etc/cockpit/notify.env`, `sudo systemctl restart cockpit-web`, re-run
`cockpit notify --check`. Rotate `COCKPIT_NOTIFY_KEY` on every remote client at the same time.
