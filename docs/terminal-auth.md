# Web terminal auth

The browser terminal (`/ws/pty`) is gated behind GitHub sign-in. There are no
shared terminal tokens to leak, rotate, or steal.

## How it works

1. You click **Sign in with GitHub** in the terminal pane.
2. GitHub sends you back; the server checks your username — or your team
   membership — against the allowlist.
3. You get a signed, httpOnly session cookie (12 hours). Every terminal
   connection must carry it.
4. Without it, the server kills the connection immediately (close code 4401)
   before anything runs.

## Operator setup

Takes about five minutes. Secrets live in the systemd override on the host —
never in git.

**1. Create a GitHub OAuth app.**
github.com → Settings → Developer settings → OAuth Apps → New OAuth App.
Set the Authorization callback URL to:

```
https://<your-cockpit-host>/api/auth/github/callback
```

**2. Set the environment** (e.g. `/etc/systemd/system/cockpit-web.service.d/oauth.conf`):

| Variable | Value |
| --- | --- |
| `GITHUB_CLIENT_ID` | from the OAuth app |
| `GITHUB_CLIENT_SECRET` | from the OAuth app |
| `GITHUB_REDIRECT_URI` | the callback URL from step 1 |
| `COCKPIT_SESSION_SECRET` | random 32+ bytes (`openssl rand -hex 32`) |
| `COCKPIT_TERMINAL_USERS` | comma-separated GitHub usernames, e.g. `dezcode,monaecode` |
| `COCKPIT_TERMINAL_TEAMS` | comma-separated `org:team` slugs (optional) |

**3. Restart the service.**

```bash
sudo systemctl daemon-reload && sudo systemctl restart cockpit-web.service
```

**Fail-closed:** until steps 1–2 are done, the terminal refuses every
connection. That is the safe default — the API and health checks keep working.

## What you'll see

| State | Terminal pane shows |
| --- | --- |
| Signed out | "Sign in with GitHub" button |
| Signed in, not allowlisted | "no terminal access" + sign-out |
| Signed in, allowlisted | your shell |

## Notes

- Agents never get their own terminal credentials. They act inside the
  owning user's signed-in session, and the user is logged with every session.
- Devices register on first sign-in. A device list / revoke UI is tracked in
  issue #23.
- Sessions expire after 12 hours; signing in again takes one click.
- Logout is `POST /api/auth/logout`, or the sign-out button in the pane.
