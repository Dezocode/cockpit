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

export function SetupPage() {
  return (
    <div className="p-3 text-sm">
      <h2 className="mb-2 text-cyan-300">SETUP</h2>
      <p className="text-slate-400">Auth, provider, model, git, plugins, audit — TUI SETUP pane intact.</p>
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

export function ModelsPage() {
  const models = [
    "claude-sonnet-5",
    "composer-2.5",
    "gpt-5.6-sol-high",
    "gemini-3.8-flash-high",
    "frontier-subscription",
  ];
  return (
    <div className="p-3 text-sm">
      <h2 className="mb-2 text-cyan-300">MODELS</h2>
      <p className="mb-2 text-slate-400">Envelope: frontier_subscription only — local Qwen / sol-v1.7.1 denied.</p>
      <ul className="space-y-1">
        {models.map((m) => (
          <li key={m} className="rounded border border-slate-700 px-2 py-1">{m}</li>
        ))}
      </ul>
    </div>
  );
}
