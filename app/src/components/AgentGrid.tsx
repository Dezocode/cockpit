import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import { GhuiChip } from "./GhuiChip";
import { useCockpitStore } from "../stores/cockpit";
import type { Agent } from "../lib/types";

function statusTone(status: Agent["status"]): "cyan" | "yellow" {
  return status === "running" ? "cyan" : "yellow";
}

export function AgentGrid() {
  const { data } = useQuery({ queryKey: ["agents"], queryFn: api.agents });
  const selected = useCockpitStore((s) => s.selectedAgentId);
  const setSelected = useCockpitStore((s) => s.setSelectedAgent);

  const agents = data?.agents ?? [];

  return (
    <div className="flex h-full flex-col gap-2 p-2">
      <header className="flex items-center justify-between border-b border-slate-700 pb-2">
        <span className="text-sm text-cyan-300">Agents ({agents.length})</span>
        <GhuiChip label={`seed ${data?.seed ?? "—"}`} tone="yellow" />
      </header>
      <div className="grid flex-1 grid-cols-2 gap-2 overflow-auto md:grid-cols-3 lg:grid-cols-4">
        {agents.map((agent) => (
          <button
            key={agent.id}
            type="button"
            onClick={() => setSelected(agent.id)}
            className={`rounded border p-2 text-left text-xs transition ${
              selected === agent.id
                ? "border-cyan-400 bg-cyan-950/40"
                : "border-slate-700 bg-slate-900/50 hover:border-slate-500"
            }`}
          >
            <div className="mb-1 flex items-center justify-between gap-1">
              <strong className="truncate">{agent.name}</strong>
              <GhuiChip label={agent.status} tone={statusTone(agent.status)} />
            </div>
            <div className="text-slate-400">{agent.provider} · {agent.model}</div>
            <div className="truncate text-slate-500">{agent.project}@{agent.branch}</div>
          </button>
        ))}
      </div>
    </div>
  );
}
