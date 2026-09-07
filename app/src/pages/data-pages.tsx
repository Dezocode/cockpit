import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import { GhuiChip } from "../components/GhuiChip";
import { ModelsView } from "./ModelsView";

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
  const [showModels, setShowModels] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "m" || e.key === "M") setShowModels((v) => !v);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    if (window.location.hash === "#MODEL") setShowModels(true);
  }, []);

  return (
    <div className="flex h-full flex-col p-3 text-sm">
      <header className="mb-2 flex items-center justify-between">
        <h2 className="text-cyan-300">COMPUTERS</h2>
        <GhuiChip
          label={showModels ? "view m · MODELS" : "view m · nodes"}
          tone={showModels ? "cyan" : "yellow"}
          onClick={() => setShowModels((v) => !v)}
        />
      </header>
      {showModels ? (
        <ModelsView />
      ) : (
        <>
          <p className="mb-2 text-xs text-slate-500">
            Hermes = Deck receipt node (not an AGENT provider). Tailnet offline ≤3s.
          </p>
          <ul className="space-y-2 overflow-auto">
            {(data?.computers ?? []).map((c) => (
              <li
                key={c.id}
                className="flex items-center justify-between rounded border border-slate-700 p-2"
              >
                <span>
                  {c.name}
                  {c.role === "hermes" && (
                    <span className="ml-2 text-xs text-yellow-400">Hermes · Deck receipt</span>
                  )}
                </span>
                <div className="flex gap-2">
                  <GhuiChip label={c.status} tone={c.status === "online" ? "cyan" : "yellow"} />
                  <GhuiChip label={`${c.latencyMs}ms`} tone="yellow" />
                </div>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}
