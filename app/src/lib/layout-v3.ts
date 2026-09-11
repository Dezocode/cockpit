export const LAYOUT_V3_KEY = "cockpit.layout.v3";

/** Staging multiview draggable panel types (Agents / Computers / Files). */
export type StagingPanelType = "AGENTS" | "COMPUTERS" | "FILES" | "GRAPH";

export interface StagingPanelState {
  id: string;
  type: StagingPanelType;
}

export interface LayoutV3 {
  version: 3;
  panels: StagingPanelState[];
  serialized?: string;
}

export function loadLayoutV3(): LayoutV3 {
  if (typeof window === "undefined") return { version: 3, panels: [] };
  try {
    const raw = localStorage.getItem(LAYOUT_V3_KEY);
    if (!raw) return { version: 3, panels: [] };
    const parsed = JSON.parse(raw) as LayoutV3;
    if (parsed.version === 3 && Array.isArray(parsed.panels)) return parsed;
  } catch {
    /* ignore corrupt layout */
  }
  return { version: 3, panels: [] };
}

export function saveLayoutV3(layout: LayoutV3): void {
  localStorage.setItem(LAYOUT_V3_KEY, JSON.stringify(layout));
}

export function newPanelId(type: StagingPanelType): string {
  return `${type}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
}
