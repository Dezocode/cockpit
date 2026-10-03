This file is the install body for published tag `v2.3.0` (`7a099ef0c382e24011d0db3c6fe4b08d40570549`). `@VERSION@` is replaced at publish. The release page is https://github.com/Dezocode/cockpit/releases/tag/v2.3.0.

`main` is ahead of that tag. C6 (`5af4f9706fda93acf074f0413a06344b1cfa40fa`, merge `0f8e56cdde8d1ee77e2d91ffa8e9c01ae3b58e5b`) is not inside the tag. Do not move the tag. Voice CLEAR and GIFs are open residuals. A local read is not CLEAR. Notes: docs/release-notes-v2.3.0-draft.md.

## Install cockpit @VERSION@

Every asset is listed in `SHA256SUMS`. Verify your download first (assets you did not download are reported as missing):

```bash
shasum -a 256 -c SHA256SUMS
```

### Linux (x64)

TUI + web tarball:

```bash
tar xzf cockpit-@VERSION@-linux-x64.tar.gz && cd cockpit-@VERSION@ && ./install.sh
```

Desktop app, Debian/Ubuntu:

```bash
sudo apt install ./cockpit_@VERSION@_amd64.deb
```

Desktop app, AppImage:

```bash
chmod +x cockpit_@VERSION@_amd64.AppImage && ./cockpit_@VERSION@_amd64.AppImage
```

Web-only server bundle (Hostinger / VPS): `cockpit-@VERSION@-web.tar.gz`, then `sudo ./scripts/install-hostinger.sh`.

### macOS (Apple silicon: arm64, Intel: x64)

TUI + web tarball (needs bash 4+: `brew install bash tmux fswatch`):

```bash
tar xzf cockpit-@VERSION@-darwin-arm64.tar.gz && cd cockpit-@VERSION@ && ./install.sh   # Apple silicon
tar xzf cockpit-@VERSION@-darwin-x64.tar.gz && cd cockpit-@VERSION@ && ./install.sh     # Intel
```

Desktop app: open `cockpit_@VERSION@_aarch64.dmg` (Apple silicon) or `cockpit_@VERSION@_x64.dmg` (Intel) and drag `cockpit.app` to Applications. The app is ad-hoc signed, not notarized, so clear the quarantine flag once:

```bash
xattr -dr com.apple.quarantine /Applications/cockpit.app
```
