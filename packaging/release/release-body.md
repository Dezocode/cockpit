These are draft notes for a release that has not been tagged: docs/release-notes-v2.3.0-draft.md

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
