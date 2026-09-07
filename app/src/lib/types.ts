export type AgentStatus = "idle" | "running" | "offline";

export interface Agent {
  id: string;
  name: string;
  provider: string;
  model: string;
  status: AgentStatus;
  project: string;
  branch: string;
  tags: string[];
}

export interface AgentsResponse {
  seed: string;
  version: number;
  agents: Agent[];
}

export interface HealthResponse {
  status: "green" | "yellow" | "red";
  product: string;
  seed: string;
  checks: Record<string, string>;
  gh: { authenticated: boolean; user?: string; host: string };
  timestamp: string;
}

export interface LayoutPanel {
  id: string;
  title: string;
  hidden?: boolean;
}

export interface LayoutResponse {
  seed: string;
  version: number;
  panels: LayoutPanel[];
  activePanel: string;
}

/** Dockview workspace pages — MODELS is a sub-view (`m`) inside COMPUTERS, not a panel. */
export type PageId =
  | "AGENT"
  | "FILES"
  | "DIFF"
  | "MEMORY"
  | "COMPUTERS"
  | "BENCH"
  | "PRS"
  | "SETUP"
  | "MAP"
  | "SPLASH";

export const PAGE_IDS: PageId[] = [
  "AGENT",
  "FILES",
  "DIFF",
  "MEMORY",
  "COMPUTERS",
  "BENCH",
  "PRS",
  "SETUP",
  "MAP",
];

/** 6-chip AGENT bar only — no 7th chip (gospel t847u). */
export const AGENT_BAR_CHIPS = [
  "PRS",
  "provider",
  "FILES",
  "MEMORY",
  "MODEL",
  "RESTART",
] as const;

export type AgentBarChip = (typeof AGENT_BAR_CHIPS)[number];

export interface DeviceFlowStart {
  device_code: string;
  user_code: string;
  verification_uri: string;
  expires_in: number;
  interval: number;
}

export interface DeviceFlowPoll {
  status: "pending" | "complete" | "error";
  authenticated?: boolean;
  user?: string;
  message?: string;
}
