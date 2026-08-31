# Cockpit CPR

`cockpit.cpr` is a Cockpit-native plugin. It is separate from the Codex
marketplace and does not call `codex plugin add`.

The plugin validates the tmux overlay before applying it, records an overlay
hash so repeated updates are idempotent, refreshes the toolbar with `SIGWINCH`,
and leaves the live Agent, FILES, SETUP, DIFF, and MAP processes alone by
default. Derived-view respawns require the explicit `--refresh-derived` flag
or `refresh_derived=1` in `~/.config/cockpit/cockpit.conf`.

Use it through the installed command:

```sh
cpr --check
cpr
cockpit plugin list
```

The updater never creates a tmux server or session when one is absent. It
reports that state so an attach/launch command can make the session first.
