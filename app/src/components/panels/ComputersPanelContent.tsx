import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "../../lib/api";
import { ModelsView } from "../../pages/ModelsView";
import { GhuiChip } from "../GhuiChip";
import styles from "../../panels/ComputersPanel.module.css";

export function ComputersPanelContent() {
  const { data } = useQuery({ queryKey: ["computers"], queryFn: api.computers });
  const [showModels, setShowModels] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "m" || e.key === "M") setShowModels((v) => !v);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  if (showModels) {
    return (
      <div className={styles.root}>
        <GhuiChip label="view m · MODELS" tone="magenta" onClick={() => setShowModels(false)} />
        <ModelsView />
      </div>
    );
  }

  return (
    <div className={styles.root}>
      <div className={styles.toolbar}>
        <GhuiChip label="view m · nodes" tone="cyan" onClick={() => setShowModels(true)} />
      </div>
      <table className="denseTable">
        <thead>
          <tr>
            <th>node</th>
            <th>status</th>
            <th>ms</th>
          </tr>
        </thead>
        <tbody>
          {(data?.computers ?? []).map((c) => (
            <tr key={c.id} className={c.role === "hermes" ? "denseRowActive" : undefined}>
              <td>
                {c.name}
                {c.role === "hermes" && <span className={styles.hermes}> · Deck</span>}
              </td>
              <td>{c.status}</td>
              <td>{c.latencyMs}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
