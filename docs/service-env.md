# Service environment

Every environment variable a Cockpit launcher, LaunchAgent plist or service unit
sets. A launcher, plist or unit sets nothing that is not listed here
(`tests/test-launchd-plist.sh` checks the plist, the systemd unit and
`bin/cockpit-web` against this table). Mode and security toggles default off.

| Variable | Meaning | `bin/cockpit-web`, `scripts/start-dist-server.sh` | launchd plist (`install.sh` on macOS) | systemd unit `packaging/systemd/cockpit-web.service` (Hostinger) |
|---|---|---|---|---|
| `COCKPIT_WEB_PORT` | API listen port (server default `8787`) | defaults to `8787` | written only when it is 1–5 digits; any other value is dropped with `launchd: ignoring non-numeric COCKPIT_WEB_PORT` | `8787` |
| `COCKPIT_WEB_HOST` | API bind address (server default `127.0.0.1`; empty also means `127.0.0.1`) | `bin/cockpit-web` defaults to `127.0.0.1` | `127.0.0.1` | not set (server default) |
| `COCKPIT_INSTALL_ROOT` | install root used by `bin/cockpit-web` and the heal script | inherited (`start-dist-server.sh` defaults it to the checkout) | the root passed to `install.sh`, when there is one | `/opt/cockpit` |
| `PATH` | where `node` is found | inherited | node's dir, Homebrew, `~/.local/bin`, system dirs | systemd default |
| `COCKPIT_HOSTINGER` | Hostinger mode: `1` → health `checks.hostinger` is `configured`, `status` needs the web + API build, and `COCKPIT_LOCAL_TRUST` is ignored | inherited, never defaulted (unset → local mode) | never written | `1` — the only unit that sets it; `scripts/install-hostinger.sh` installs this unit and also exports `1` for its own run |
| `NODE_ENV` | Node runtime mode | not set | not set | `production` |

`COCKPIT_LOCAL_TRUST` and the notify secrets are never set by a launcher, plist
or unit: local trust is an explicit opt-in on a local launch, and the Hostinger
unit reads secrets only from `EnvironmentFile=-/etc/cockpit/notify.env`
(see [notify.md](notify.md)). Env and config files are data; no Cockpit script sources them.
