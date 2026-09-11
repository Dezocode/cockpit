import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import { GhuiChip } from "./GhuiChip";
import { useCockpitStore } from "../stores/cockpit";
import type { Agent } from "../lib/types";
import type { ChipTone } from "./GhuiChip";
import styles from "./AgentGrid.module.css";

function statusTone(status: Agent["status"]): ChipTone {
  return status === "running" ? "magenta" : "warn";
}

export function AgentGrid() {
  const { data } = useQuery({ queryKey: ["agents"], queryFn: api.agents });
  const selected = useCockpitStore((s) => s.selectedAgentId);
  const setSelected = useCockpitStore((s) => s.setSelectedAgent);
  const agents = data?.agents ?? [];

  return (
    <div className={styles.root}>
      <header className={styles.header}>
        <span>Agents ({agents.length})</span>
        <GhuiChip label={`seed ${data?.seed ?? "—"}`} tone="cyan" />
      </header>
      <div className={styles.grid}>
        {agents.map((agent) => (
          <button
            key={agent.id}
            type="button"
            onClick={() => setSelected(agent.id)}
            className={`${styles.card} ${selected === agent.id ? styles.cardActive : ""}`}
          >
            <div className={styles.cardHead}>
              <strong className={styles.name}>{agent.name}</strong>
              <GhuiChip label={agent.status} tone={statusTone(agent.status)} />
            </div>
            <div className={styles.meta}>{agent.provider} · {agent.model}</div>
            <div className={styles.branch}>{agent.project}@{agent.branch}</div>
          </button>
        ))}
      </div>
    </div>
  );
}
