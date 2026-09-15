# Cockpit v2.2.2

Patch release.

## Security: web terminal now requires GitHub sign-in

- `/ws/pty` accepted unauthenticated WebSocket connections and spawned a shell
  as the service user (issue #16, critical). Fixed in PR #22, merged and
  deployed 2026-09-15.
- Every terminal connection now needs a signed session tied to a GitHub OAuth
  identity. Access is granted by username (`COCKPIT_TERMINAL_USERS`) or GitHub
  team (`COCKPIT_TERMINAL_TEAMS`).
- Agents hold no terminal credentials of their own; they act inside the
  owning user's session.
- Fail-closed: without OAuth configured, the terminal refuses all connections
  (close code 4401). Verified live on production.
- Operator setup: [docs/terminal-auth.md](docs/terminal-auth.md).

## Docs

- New operator guide for terminal auth (`docs/terminal-auth.md`).
- Security finding doc for #16 marked fixed.
- Deploy README points at the new guide.
