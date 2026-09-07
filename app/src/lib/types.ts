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

export type PageId =
  | "AGENT"
  | "FILES"
  | "DIFF"
  | "MEMORY"
  | "COMPUTERS"
  | "MODELS"
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
  "MODELS",
  "BENCH",
  "PRS",
  "SETUP",
  "MAP",
];
