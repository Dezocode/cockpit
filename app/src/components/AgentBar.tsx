import { GhuiChip } from "./GhuiChip";
import { AGENT_BAR_CHIPS, type AgentBarChip, type PageId } from "../lib/types";
import { useCockpitStore } from "../stores/cockpit";

interface AgentBarProps {
  onChip: (chip: AgentBarChip) => void;
  providerLabel?: string;
}

export function AgentBar({ onChip, providerLabel = "AGENT" }: AgentBarProps) {
  const activePage = useCockpitStore((s) => s.activePage);

  const tone = (chip: AgentBarChip): "cyan" | "yellow" => {
    if (chip === "provider") return "cyan";
    if (chip === "PRS" && activePage === "PRS") return "cyan";
    if (chip === "FILES" && activePage === "FILES") return "cyan";
    if (chip === "MEMORY" && activePage === "MEMORY") return "cyan";
    if (chip === "MODEL" && activePage === "COMPUTERS") return "cyan";
    return "yellow";
  };

  const label = (chip: AgentBarChip) => (chip === "provider" ? providerLabel : chip);

  return (
    <div className="flex flex-wrap items-center gap-1 border-b px-2 py-1" style={{ borderColor: "var(--cockpit-border-muted)", background: "var(--cockpit-surface)" }}>
      <span className="mr-1 text-xs font-bold" style={{ color: "var(--cockpit-chrome)" }}>cockpit</span>
      {AGENT_BAR_CHIPS.map((chip) => (
        <GhuiChip
          key={chip}
          label={label(chip)}
          tone={tone(chip)}
          active={tone(chip) === "cyan"}
          onClick={() => onChip(chip)}
        />
      ))}
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
