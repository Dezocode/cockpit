Voice: PENDING owner ear (a local read is not CLEAR). Tree these drafts describe: `cockpit-gtm-v2.3` @ `94b035ae768d8c9d2ad49f30ab6d493853855d66`. Nothing has been tagged `2.3.0`.

Read this out loud while you do it. Budget about ten minutes the first time, longer if pnpm has to fetch Cesium. You need git, Node 22, pnpm 9, and tmux. On a Mac, install bash 4, tmux, and fswatch from Homebrew before `./install.sh`.

1. Clone and leave `main` immediately.

```bash
git clone https://github.com/Dezocode/cockpit.git
cd cockpit
git checkout cockpit-gtm-v2.3
git rev-parse HEAD
```

Say the SHA out loud. You want `94b035ae768d8c9d2ad49f30ab6d493853855d66`. If you see `968ad491c073c68c1623d47e65ec83a2fd2ed8e1`, you are on `main` and the rest of this script will not match the tree.

2. Check the version the branch actually claims.

```bash
node -p "require('./app/package.json').version"
git describe --tags --abbrev=0
```

The first command prints `2.3.0-dev`. The second prints `v2.2.2`. That gap is the point of the demo. The branch is ahead of the tag, and the tag has not moved.

3. Install the tmux side the way the README tells you.

```bash
./install.sh
```

On macOS, if install complains about bash, stop and run `brew install bash tmux fswatch`, then run `./install.sh` again under that bash. Linux with `inotifywait` already on `PATH` does not need `fswatch`.

4. Start the API on loopback and hit health before you open a browser.

```bash
cockpit-web
```

Leave that process up. In another terminal:

```bash
curl -sS http://127.0.0.1:8787/api/health
ss -ltnp | rg 8787 || netstat -an | rg 8787
```

You want a health JSON body, and you want the listen address to be `127.0.0.1:8787`, not `0.0.0.0`. If `cockpit-web` is missing because you have not installed the scripts onto `PATH`, run it from the repo with `pnpm --dir app exec tsx server/index.ts` after `pnpm --dir app install`. Same port, same host default.

5. Start the UI dev server. It proxies `/api` to port 8787, and Vite is pinned to port 1420.

```bash
pnpm --dir app install
pnpm --dir app dev
```

Open `http://127.0.0.1:1420/splash/staging`. If the splash is in the way, use the control that routes to `/splash/staging`, or paste that path.

6. Add the globe. In the palette, double-click the chip labeled `GODSEYE`. The panel title becomes `GOD'S EYE`. The first paint says it is initialising, because the Cesium chunk is lazy. When the canvas is up, the stack control (`#godseye-stack`) is on Natural Earth. You should see a credit for Natural Earth II. You should not be asked for a Cesium ion token.

Click a placed computer if one shows up. Machines the snapshot cannot put on a centroid stay in the unplaced list under the canvas. If WebGL cannot start, the panel text switches to the computers roster. That is the error boundary, not a second product.

7. Send a notification that does not leave the machine.

```bash
cockpit notify --check --json
cockpit notify --dry-run --json "demo from the 2.3 branch"
```

`--check` reports whether telegram, ntfy, and desktop are `ready`, `not-configured`, or `invalid`. It does not send. The dry run prints a receipt whose `delivered` field is `dry-run`. If Hermes is on `PATH`, or you already exported `COCKPIT_TELEGRAM_BOT_TOKEN` and `COCKPIT_TELEGRAM_CHAT_ID`, `--check` can report telegram as ready. Stop at the receipt anyway. This script does not send.

8. Stop on a tag check.

```bash
git tag -l 'v2.3*'
git tag -l 'v2.2.2'
```

The first command prints nothing. The second prints `v2.2.2`. You are done. The globe you opened did not ask for a key, the health check was on `127.0.0.1:8787`, and the notify receipt said `dry-run`.
