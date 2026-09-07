import { motion } from "framer-motion";

type ChipTone = "cyan" | "yellow";

interface GhuiChipProps {
  label: string;
  tone?: ChipTone;
  onClick?: () => void;
  active?: boolean;
}

export function GhuiChip({ label, tone = "cyan", onClick, active }: GhuiChipProps) {
  const cls = tone === "cyan" ? "ghui-chip-cyan" : "ghui-chip-yellow";
  return (
    <motion.button
      type="button"
      whileTap={{ scale: 0.97 }}
      className={`rounded px-2 py-0.5 text-xs ${cls} ${active ? "ring-2 ring-white/30" : ""}`}
      onClick={onClick}
    >
      {label}
    </motion.button>
  );
}
