Status: PARTIAL. Voice CLEAR is an open residual. Owner Dezocode is away. A local read is not CLEAR. GIFs are an open residual. These notes do not attach GIFs.

These notes describe the published tag and what `main` has past it. They do not move the tag.

## Published tag

Lightweight tag `v2.3.0` is `7a099ef0c382e24011d0db3c6fe4b08d40570549` (`Set version to 2.3.0 for the v2.3.0 tag (t1127u)`). The release page is <https://github.com/Dezocode/cockpit/releases/tag/v2.3.0>. `app/package.json` and `app/src-tauri/Cargo.toml` on that commit say `2.3.0`.

Assets on that release, observed 2026-10-02:

- `cockpit-2.3.0-linux-x64.tar.gz`
- `cockpit-2.3.0-web.tar.gz`
- `cockpit-2.3.0-darwin-arm64.tar.gz`
- `cockpit-2.3.0-darwin-x64.tar.gz`
- `cockpit_2.3.0_amd64.deb`
- `cockpit_2.3.0_amd64.AppImage`
- `cockpit_2.3.0_aarch64.dmg`
- `cockpit_2.3.0_x64.dmg`
- `SHA256SUMS`

The install text those assets use is `packaging/release/release-body.md`, with `@VERSION@` replaced at publish. A fresh Hostinger install of this tag was green. `gh_auth` on that install is still pending. That residual belongs to C9, not to this pack. The notify body `Cockpit v2.3.0 GTM done` was already delivered.

## `main` is ahead of the tag

`main`, when this pack was written, is `0e7e9d62d546bf969c433c469d74361fc77c382b` (`docs: regenerate architecture docs [skip ci]`). It is architecture docs on merge `0f8e56cdde8d1ee77e2d91ffa8e9c01ae3b58e5b` of pull request #40. Parents of that merge: `de29184552925a347edd6ae5fe4d78e83dc671b4` and `5af4f9706fda93acf074f0413a06344b1cfa40fa`.

C6 is in that range and is not in the tag. `git merge-base --is-ancestor 5af4f9706fda93acf074f0413a06344b1cfa40fa 7a099ef0c382e24011d0db3c6fe4b08d40570549` is false. God's Eye View onboarding (`5aa675c3ba7e415a4cc6e81ac8f00ce5bb9242b3`: `scripts/get-cockpit.sh`, `bin/cockpit-doctor`, `pinokio/`) is part of C6 and is not inside the tag.

Also ahead of the tag, and not C6: C9-next merge `e01792f797b5ba5d10ad0481352a199175786620` (pull request #41) and the architecture-doc commits listed above. Do not retag `v2.3.0` to pick them up.

## Inside the tag

C5 Laya is on `main` and is inside the tag. Merge `e6e4ae2d2f59502d6c60e4b46bbea8f385163be8` (pull request #34) is an ancestor of `7a099ef`. C5-next merge `60e5f3be8ec5c21902e704fa31029b15aa722f68` (pull request #39) is an ancestor of the tag too. `bin/cockpit-laya` is on the tag. `bin/cockpit-doctor` is not.

The integration merge into `main` that carries the tag's tree is `4cf9b49575963643e5581f0989c0ad86fb6bbd9a` (pull request #25), then `7a099ef` sets the version to `2.3.0`.

## What this pack does not claim

Voice is not CLEAR. There are no GIFs. `gh_auth` is not closed. This file does not score CI on the launch-pack pull request. A local read is not a Proctor score.
