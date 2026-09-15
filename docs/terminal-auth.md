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

**2. Create the systemd drop-in.** These values have to reach the system
service — exporting them in your own shell is not enough. Generate a session
secret, then write the drop-in:

```bash
SESSION_SECRET=$(openssl rand -hex 32)
sudo mkdir -p /etc/systemd/system/cockpit-web.service.d
sudo tee /etc/systemd/system/cockpit-web.service.d/oauth.conf > /dev/null <<EOF
[Service]
Environment=GITHUB_CLIENT_ID=<from the OAuth app>
Environment=GITHUB_CLIENT_SECRET=<from the OAuth app>
Environment=GITHUB_REDIRECT_URI=https://<your-cockpit-host>/api/auth/github/callback
Environment=COCKPIT_SESSION_SECRET=$SESSION_SECRET
Environment=COCKPIT_TERMINAL_USERS=dezcode,monaecode
Environment=COCKPIT_TERMINAL_TEAMS=
EOF
sudo chmod 600 /etc/systemd/system/cockpit-web.service.d/oauth.conf
```

| Variable | Value |
| --- | --- |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` / `GITHUB_REDIRECT_URI` | from the OAuth app (step 1) |
| `COCKPIT_SESSION_SECRET` | random 32+ bytes |
| `COCKPIT_TERMINAL_USERS` | comma-separated GitHub usernames |
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
