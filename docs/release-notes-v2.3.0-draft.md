Voice: PENDING owner ear (a local read is not CLEAR). Tree these drafts describe: `cockpit-gtm-v2.3` @ `94b035ae768d8c9d2ad49f30ab6d493853855d66`. Nothing has been tagged `2.3.0`.

These are draft notes for a release that has not been tagged. There is no `v2.3.0` tag, `main` has not moved, and the newest tag is still `v2.2.2`.

Compare these notes to `cockpit-gtm-v2.3` at `94b035ae768d8c9d2ad49f30ab6d493853855d66`, the merge of pull request #35 on 2026-09-29 at 4:24pm CT. `app/package.json` and `app/src-tauri/Cargo.toml` both say `2.3.0-dev`, and the asset names CI produced use that same string.

### Integration branch, not the default checkout

Pull requests #13, #14, and #15 were merged into `cockpit-gtm-v2.3` (the integration pull request is #25, still a draft aimed at `main`). `e84669b`, the visual multiview commit, is an ancestor of this branch and is not an ancestor of `origin/main`. Staging lives at `/splash/staging`. The dock palette can open AGENTS, COMPUTERS, FILES, and GOD'S EYE in one layout, saved under `cockpit.layout.v3`.

### Deploy scripts collapsed

Pull request #26 (`e7a1687`) and the follow-up #28 (`d642070`) leave a single Hostinger installer, `scripts/install-hostinger.sh`. The `bin/codex-cockpit*` shim set is gone (39 files), and so are `deploy/hostinger-grok-build-install.sh`, `scripts/hostinger-grok-build.sh`, `deploy/cockpit-web.service`, and `deploy/nginx-cockpit.conf`.

### Loopback bind, fswatch, and a LaunchAgent

Pull request #27 (`c01379a`) and #36 (`c38501a`) are on this branch. The web server defaults to `http://127.0.0.1:8787`. `bin/cockpit-portable-lib` uses `inotifywait` when it exists and `fswatch` otherwise. Darwin installs a LaunchAgent instead of a systemd user unit, and that plist does not default `COCKPIT_HOSTINGER`. Local launchers do not default it either. `packaging/systemd/cockpit-web.service` still sets `Environment=COCKPIT_HOSTINGER=1` for the Hostinger install. On macOS, `./install.sh` expects `brew install bash tmux fswatch` so you are not stuck on bash 3.2.

### What the CI jobs actually built

On `94b035a`, CI runs `36633161689` (push) and `36633167175` (pull request) succeeded for `versions`, `verify`, `shell-tests`, `portability (ubuntu-latest)`, `portability (macos-14)`, `portability (macos-15-intel)`, `desktop (ubuntu-latest)`, `desktop (macos-14)`, and `desktop (macos-15-intel)`. Setup pins Node 22.

Release workflow run `36633167366` (pull request, same SHA) succeeded at `bundle (linux-x64)`, `bundle (darwin-arm64)`, `bundle (darwin-x64)`, `desktop (ubuntu-22.04)`, `desktop (macos-14)`, `desktop (macos-15-intel)`, and `verify-assets`. The log line is `release-assets: 9/9 present (version 2.3.0-dev)`, with `SHA256SUMS` covering the other eight:

- `cockpit-2.3.0-dev-linux-x64.tar.gz` (6,355,411 bytes)
- `cockpit-2.3.0-dev-web.tar.gz` (5,706,549 bytes)
- `cockpit-2.3.0-dev-darwin-arm64.tar.gz` (6,355,089 bytes)
- `cockpit-2.3.0-dev-darwin-x64.tar.gz` (6,355,085 bytes)
- `cockpit_2.3.0-dev_amd64.deb` (8,663,044 bytes)
- `cockpit_2.3.0-dev_amd64.AppImage` (86,895,096 bytes)
- `cockpit_2.3.0-dev_aarch64.dmg` (8,085,221 bytes)
- `cockpit_2.3.0-dev_x64.dmg` (8,328,153 bytes)

`publish` on that run was skipped. The workflow only publishes when the event is a tag push matching `v2.*`. `app/src-tauri/tauri.conf.json` sets `macOS.signingIdentity` to `-`, and `packaging/release/release-body.md` says the app is ad-hoc signed, not notarized, and tells you to clear `com.apple.quarantine` once. Those files were Actions artifacts of run `36633167366`. They are not a Release you can open on the repo today.

### God's Eye panel

Pull requests #29 (`012df57`) and #31 (`c44119d`) add the panel under `app/src/panels/godseye/`. It is a lazy Cesium viewer on `cesium@1.138.0`. `vite-plugin-static-copy` copies the workers, and `CESIUM_BASE_URL` is `/cesium`. The default stack id is `naturalearth`, and the credit line reads "Natural Earth II (public domain, bundled with Cesium)". Markers come from a snapshot of `/api/computers`. The entry component suspends while the chunk loads, and its error boundary renders the computers roster if WebGL fails. Code was ported from `bilawalsidhu/gods-eye-view` @ `b210ab0` (MIT). The port map is `third_party/gods-eye-view/PORTMAP.tsv`.

### `cockpit notify`

Pull request #30 (`24c838f`), plus lint follow-ups #32 (`82d7497`) and #33 (`dff0a6b`), adds `bin/cockpit-notify`, `POST /api/notify`, and `GET /api/notify/status`.

```
cockpit notify [--title T] [--sink auto|telegram|ntfy|desktop|all] [--require SINK]
               [--priority low|default|high] [--link URL] [--id ID] [--json] [--dry-run]
               [--check] [--via local|api] [--] MESSAGE... | -
```

The process exits 0 when something was delivered, 2 on a bad invocation, 3 when nothing was delivered, 4 when the API refuses the caller, and 5 when the caller is rate limited. `--id` dedupes inside `dedupe_window_s` (default 600 seconds). Receipts go to `${XDG_STATE_HOME:-~/.local/state}/cockpit/notify.jsonl` mode `0600`, with a hash and an 80-character preview, not the token. Callers for the HTTP route are a GitHub OAuth session cookie on the terminal allowlist, `Authorization: Bearer $COCKPIT_NOTIFY_KEY` compared as SHA-256 with `timingSafeEqual`, or `COCKPIT_LOCAL_TRUST=1` on a loopback peer. `COCKPIT_HOSTINGER=1` turns that local-trust path off, which is what the Hostinger unit does.

### Terminal auth, unchanged

`/ws/pty` still requires the OAuth session. If that session is not configured, the socket closes with `4401`.
