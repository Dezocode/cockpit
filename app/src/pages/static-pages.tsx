import { AgentGrid } from "../components/AgentGrid";
import { TerminalPane } from "../components/TerminalPane";
import { useCockpitStore } from "../stores/cockpit";

export function AgentPage() {
  const selected = useCockpitStore((s) => s.selectedAgentId);
  return (
    <div className="grid h-full grid-rows-2 gap-1">
      <AgentGrid />
      <TerminalPane agentId={selected ?? undefined} />
    </div>
  );
}

export function FilesPage() {
  return (
    <div className="p-3 text-sm">
      <h2 className="mb-2 text-cyan-300">FILES</h2>
      <p className="text-slate-400">Neovim follower — parallel TUI pane preserved via <code>cockpit files</code>.</p>
      <ul className="mt-2 list-inside list-disc text-slate-300">
        <li>Event-driven file watch (inotify policy from cockpit-lib)</li>
        <li>Follows agent-written paths</li>
      </ul>
    </div>
  );
}

export function DiffPage() {
  return (
    <div className="p-3 text-sm">
      <h2 className="mb-2 text-cyan-300">DIFF</h2>
      <p className="text-slate-400">Scoped git diff — staged / working / untracked bands.</p>
    </div>
  );
}

export function MapPage() {
  return (
    <div className="p-3 text-sm">
      <h2 className="mb-2 text-cyan-300">MAP</h2>
      <p className="text-slate-400">Mermaid via cockpit-showmegraphs adapter.</p>
    </div>
  );
}

import { useState } from "react";
import { ThemeSwitcher } from "../components/ThemeSwitcher";
import { loadTheme, type CockpitTheme } from "../lib/theme";
import styles from "../panels/SetupPanel.module.css";

export function SetupPage() {
  const [theme, setTheme] = useState<CockpitTheme>(loadTheme);

  return (
    <div className={styles.root}>
      <p className={styles.note}>
        Auth, provider, model, git, plugins, audit — TUI SETUP pane intact. Envelope: frontier_subscription.
      </p>
      <ThemeSwitcher value={theme} onChange={setTheme} />
      <ul className={styles.list}>
        <li>GitHub device-flow via gh keyring</li>
        <li>PTY web + desktop (tauri-plugin-pty)</li>
        <li>Origin ≠ intercom bus</li>
      </ul>
    </div>
  );
}

export function PrsPage() {
  return (
    <div className="p-3 text-sm">
      <h2 className="mb-2 text-cyan-300">PRS</h2>
      <p className="text-slate-400">GitHub PR dashboard via gh CLI.</p>
    </div>
  );
}

export function BenchPage() {
  return (
    <div className="p-3 text-sm">
      <h2 className="mb-2 text-yellow-300">BENCH</h2>
      <p className="text-slate-400">Read-only Proctor surface. Harness under <code>bench/cockpit/</code>.</p>
      <pre className="mt-2 rounded bg-black/40 p-2 text-xs">pnpm test:matrix{"\n"}pnpm test:doctor</pre>
    </div>
  );
}

