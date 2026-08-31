# Cockpit Intercom

`cockpit.intercom` is a Cockpit-native plugin. It is separate from the Codex
marketplace and does not call `codex plugin add`.

The plugin gates on the existing GitHub provider. Proof commands are
`gh auth status -h github.com` and `gh repo view Dezocode/intercom`. When
GitHub is not signed in, use:

```sh
gh auth login -h github.com -p https -w
```

Work is limited to the `Dezocode/intercom` repository over HTTPS using that
`gh` identity. The plugin clones or fetches the repo, writes only
`peers/<id>.md`, and commits plus pushes to `main` per intercom `AGENTS.md`.
It never adds `auth.json`, never deletes another peer's file, and never
rebases shared history.

Use it through the installed command:

```sh
intercom auth-check
intercom status
intercom sync
intercom write --id my-peer --message "progress marker" peers/my-peer.md
cockpit plugin list
```

Clone location defaults to `~/intercom` and can be overridden with
`COCKPIT_INTERCOM_HOME`. Peer id defaults from `COCKPIT_INTERCOM_PEER_ID`.
