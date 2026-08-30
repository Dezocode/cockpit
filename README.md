# Codex Cockpit

One tmux session named `codex-cockpit`. A second launch attaches that
runtime; leftover `codex-cockpit-*` sessions with no clients are reaped so
ghost Codex processes do not accumulate.

One tmux workspace, two equal profiles, switched live:

At launch a **keyboard-only** screen asks `desktop | touch`. If it idles, the
next **key** is desktop and the next **tap/click** is touch. After attach the
same idle probe runs: typing does not get stolen until you go idle, then the
first key or click flips the layout.

Endpoint size still wins for fit: phone-sized clients stay on tabs.

| Profile | Detected when | Chrome |
| --- | --- | --- |
| **Foot / Omarchy** | local Foot, `xdg-terminal-exec`, Wayland | 2×2 pad, status top, prefix `Ctrl-Space` |
| **Termius iOS** | iPhone SSH footprint (Tailscale `100.64/10`, `tailscaled`→`login`, no `COLORTERM`, or `TERM_PROGRAM=Termius`) | full-screen tabs, status bottom, prefix `Ctrl-B`, F1–F6, long-press menu |

Local Foot wins if both clients are attached, so the Omarchy pad is not crushed by a 54-column phone.

Views (same in both profiles):

- **CODEX** — live runtime, approvals, applied edits
- **FILES** — Neovim, following files Codex just wrote
- **DIFF** — scoped, event-driven patch
- **MAP** — browserless Mermaid
- **PRS** — GitHub PRs

```bash
codex
```

From Omarchy/Foot:

```bash
omarchy launch tui codex-cockpit
```

`Super+Alt+C` launches the cockpit in Foot. `Super+Alt+K` is Omarchy's tmux key list. `codex-cli` is the raw CLI.

`prefix + k` forces desktop/keyboard. `prefix + t` forces touch/mobile.
`prefix + A` opens a nested auth box from `~/.config/codex-cockpit/providers.conf`
(GitHub is `gh auth login` web OAuth). Click outside the box to cancel; it
closes after success. Add more `[provider]` blocks for other sources — Codex
CLI and Grok logins stay with those tools and are not listed by default.

Watchers stay blocked on inotify while idle. Hidden or zoomed-away views only set a dirty bit; the visible pad (Foot) or the open tab (Termius) refreshes after a coalesced burst of file events. Detached idle only keeps profile state on disk (`~/.config/codex-cockpit/state`).

## Install

```bash
./install.sh
```

Requires tmux, a Codex CLI on `PATH`, and (for PRs) GitHub CLI. Unsigned
`gh` does not block the Codex runtime; the PR pane and `prefix + G` open a
nested OAuth box you can click out of.

## License

MIT. Do not commit API tokens, `~/.codex/auth.json`, or Grok credentials.
