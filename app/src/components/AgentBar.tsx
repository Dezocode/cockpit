import { GhuiChip } from "./GhuiChip";
import { AGENT_BAR_CHIPS, type AgentBarChip, type PageId } from "../lib/types";
import { useCockpitStore } from "../stores/cockpit";
import styles from "./AgentBar.module.css";

interface AgentBarProps {
  onChip: (chip: AgentBarChip) => void;
  providerLabel?: string;
}

function isChipActive(chip: AgentBarChip, activePage: PageId): boolean {
  switch (chip) {
    case "PRS":
      return activePage === "PRS";
    case "FILES":
      return activePage === "FILES";
    case "MEMORY":
      return activePage === "MEMORY";
    case "MODEL":
      return activePage === "COMPUTERS";
    case "provider":
      return activePage === "SETUP";
    default:
      return false;
  }
}

export function AgentBar({ onChip, providerLabel = "AGENT" }: AgentBarProps) {
  const activePage = useCockpitStore((s) => s.activePage);
  const label = (chip: AgentBarChip) => (chip === "provider" ? providerLabel : chip);

  return (
    <div className={styles.bar}>
      <span className={styles.brand}>cockpit</span>
      {AGENT_BAR_CHIPS.map((chip) => {
        const active = isChipActive(chip, activePage);
        return (
          <GhuiChip
            key={chip}
            label={label(chip)}
            tone={active ? "magenta" : "cyan"}
            active={active}
            onClick={() => onChip(chip)}
          />
        );
      })}
    </div>
  );
}

export function chipToPage(chip: AgentBarChip): PageId | null {
  switch (chip) {
    case "PRS":
      return "PRS";
    case "FILES":
      return "FILES";
    case "MEMORY":
      return "MEMORY";
    case "MODEL":
      return "COMPUTERS";
    case "provider":
      return "SETUP";
    default:
      return null;
  }
}
