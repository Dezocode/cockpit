import type { ReactNode } from "react";
import styles from "./FieldsetPanel.module.css";

interface FieldsetPanelProps {
  title: string;
  children: ReactNode;
  className?: string;
}

export function FieldsetPanel({ title, children, className }: FieldsetPanelProps) {
  return (
    <section className={`${styles.fieldset} ${className ?? ""}`} aria-label={title}>
      <span className={styles.legend}>{title}</span>
      <div className={styles.body}>{children}</div>
    </section>
  );
}
