import { useQuery } from "@tanstack/react-query";
import { api } from "../../lib/api";
import { useCockpitStore } from "../../stores/cockpit";
import styles from "../../panels/AgentsPanel.module.css";

export function AgentsPanelContent() {
  const { data } = useQuery({ queryKey: ["agents"], queryFn: api.agents });
  const selected = useCockpitStore((s) => s.selectedAgentId);
  const setSelected = useCockpitStore((s) => s.setSelectedAgent);
  const agents = data?.agents ?? [];

  return (
    <div className={styles.root}>
      <div className={styles.header}>
        <span>Agents ({agents.length})</span>
        <span className={styles.meta}>seed {data?.seed ?? "—"}</span>
      </div>
      <div className={styles.grid}>
        {agents.map((agent) => (
          <button
            key={agent.id}
            type="button"
            className={`${styles.card} ${selected === agent.id ? styles.cardActive : ""}`}
            onClick={() => setSelected(agent.id)}
          >
            <div>{agent.name}</div>
            <div className={styles.meta}>
              {agent.provider} · <span className={agent.status === "running" ? styles.badge : styles.badgeWarn}>{agent.status}</span>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
