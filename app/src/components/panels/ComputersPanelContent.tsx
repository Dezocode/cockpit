import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "../../lib/api";
import { ModelsView } from "../../pages/ModelsView";
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
        <div className={styles.note}>view m · MODELS (inside COMPUTERS)</div>
        <ModelsView />
      </div>
    );
  }

  return (
    <div className={styles.root}>
      <div className={styles.note}>Hermes = Deck receipt node — NOT AGENT provider</div>
      <div className={styles.list}>
        {(data?.computers ?? []).map((c) => (
          <div key={c.id} className={styles.row}>
            <span>
              {c.name}
              {c.role === "hermes" && <span className={styles.hermes}>Hermes · Deck</span>}
            </span>
            <span className={c.status === "online" ? styles.badge : `${styles.badge} ${styles.badgeWarn}`}>
              {c.status} · {c.latencyMs}ms
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
