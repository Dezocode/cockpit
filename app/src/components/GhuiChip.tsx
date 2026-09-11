import { motion } from "framer-motion";
import styles from "./GhuiChip.module.css";

/** cyan = idle chrome · magenta = active · warn = fail-closed / idle status only */
export type ChipTone = "cyan" | "magenta" | "warn";

interface GhuiChipProps {
  label: string;
  tone?: ChipTone;
  onClick?: () => void;
  active?: boolean;
}

export function GhuiChip({ label, tone = "cyan", onClick, active }: GhuiChipProps) {
  const cls =
    tone === "magenta" ? styles.magenta : tone === "warn" ? styles.warn : styles.cyan;
  return (
    <motion.button
      type="button"
      whileTap={{ scale: 0.97 }}
      className={`${styles.chip} ${cls} ${active ? styles.active : ""}`}
      onClick={onClick}
    >
      {label}
    </motion.button>
  );
}
