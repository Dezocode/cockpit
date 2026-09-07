import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import { GhuiChip } from "../components/GhuiChip";

export function MemoryPage() {
  const { data } = useQuery({ queryKey: ["memory"], queryFn: api.memory });
  return (
    <div className="flex h-full flex-col p-3 text-sm">
      <header className="mb-2 flex items-center gap-2">
        <h2 className="text-cyan-300">MEMORY</h2>
        {data?.failClosed && <GhuiChip label="fail-closed" tone="yellow" />}
      </header>
      <ul className="flex-1 space-y-2 overflow-auto">
        {(data?.entries ?? []).map((e) => (
          <li key={e.id} className="rounded border border-slate-700 bg-slate-900/40 p-2">
            <div>{e.title}</div>
            <div className="text-xs text-slate-500">{e.source}</div>
          </li>
        ))}
      </ul>
    </div>
  );
}

export function ComputersPage() {
  const { data } = useQuery({ queryKey: ["computers"], queryFn: api.computers });
  return (
    <div className="flex h-full flex-col p-3 text-sm">
      <h2 className="mb-2 text-cyan-300">COMPUTERS</h2>
      <p className="mb-2 text-xs text-slate-500">Tailnet remote offline threshold ≤3s</p>
      <ul className="space-y-2">
        {(data?.computers ?? []).map((c) => (
          <li key={c.id} className="flex items-center justify-between rounded border border-slate-700 p-2">
            <span>{c.name}</span>
            <div className="flex gap-2">
              <GhuiChip label={c.status} tone={c.status === "online" ? "cyan" : "yellow"} />
              <GhuiChip label={`${c.latencyMs}ms`} tone="yellow" />
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
