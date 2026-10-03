Status: PARTIAL. Voice CLEAR is an open residual. Owner Dezocode is away. A local read is not CLEAR. GIFs are an open residual. This script has no GIFs and it does not send a live notification.

Read this out loud while you do it. You need git, Node 22, pnpm 9, and tmux. On a Mac, install bash 4, tmux, and fswatch from Homebrew before `./install.sh`.

1. Clone the default branch. Do not check out `cockpit-gtm-v2.3`.

```bash
git clone https://github.com/Dezocode/cockpit.git
cd cockpit
git rev-parse HEAD
git rev-parse v2.3.0
node -p "require('./app/package.json').version"
```

`main`, when this pack was written, is `0e7e9d62d546bf969c433c469d74361fc77c382b`. If `main` has moved, say the SHA you actually see.

`v2.3.0` must print `7a099ef0c382e24011d0db3c6fe4b08d40570549`. The version string is `2.3.0` on both `main` and that tag. The tag is not `main`. C6 is ahead of the tag.

2. See the split.

```bash
git merge-base --is-ancestor 5af4f9706fda93acf074f0413a06344b1cfa40fa v2.3.0; echo c6_in_tag:$?
git merge-base --is-ancestor e6e4ae2d2f59502d6c60e4b46bbea8f385163be8 v2.3.0; echo c5_in_tag:$?
git tag -l 'v2.3.0'
```

`c6_in_tag` prints `1` (C6 is not in the tag). `c5_in_tag` prints `0` (C5 Laya is in the tag). `git tag -l` prints `v2.3.0`.

3. Install the tmux side the way the README tells you.

```bash
./install.sh
```

On macOS, if install complains about bash, stop and run `brew install bash tmux fswatch`, then run `./install.sh` again under that bash. Linux with `inotifywait` already on `PATH` does not need `fswatch`.

4. On `main`, the C6 doctor is present. It is absent on the tag.

```bash
command -v cockpit || true
cockpit doctor --json || true
git cat-file -e v2.3.0:bin/cockpit-doctor; echo doctor_on_tag:$?
```

`doctor_on_tag` is nonzero. Do not treat a missing doctor on the tag as a missing doctor on `main`.

5. Start the API on loopback and hit health before you open a browser.

```bash
cockpit-web
```

Leave that process up. In another terminal:

```bash
curl -sS http://127.0.0.1:8787/api/health
```

You want a health JSON body from `127.0.0.1:8787`. If `cockpit-web` is missing because the scripts are not on `PATH`, run `pnpm --dir app install` and then `pnpm --dir app exec tsx server/index.ts`.

6. Start the UI dev server.

```bash
pnpm --dir app install
pnpm --dir app dev
```

Open `http://127.0.0.1:1420/splash/staging`. In the palette, double-click the chip labeled `GODSEYE`. The panel title becomes `GOD'S EYE`.

7. Send a notification that does not leave the machine. Do not send the done line again. It was already delivered.

```bash
cockpit notify --dry-run --json "demo from main, not a send"
```

Stop at the dry-run receipt. This script does not send.

8. Stop on the release page, not on a claim that the tag is missing.

The page is <https://github.com/Dezocode/cockpit/releases/tag/v2.3.0>. `main` is ahead of that tag. Voice CLEAR and GIFs are still open.
