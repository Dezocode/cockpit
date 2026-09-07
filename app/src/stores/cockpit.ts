import { create } from "zustand";
import type { Agent, PageId } from "../lib/types";

interface CockpitState {
  selectedAgentId: string | null;
  activePage: PageId;
  accountId: string;
  setSelectedAgent: (id: string | null) => void;
  setActivePage: (page: PageId) => void;
  setAccountId: (id: string) => void;
}

export const useCockpitStore = create<CockpitState>((set) => ({
  selectedAgentId: null,
  activePage: "AGENT",
  accountId: "default",
  setSelectedAgent: (id) => set({ selectedAgentId: id }),
  setActivePage: (page) => set({ activePage: page }),
  setAccountId: (id) => set({ accountId: id }),
}));

interface AgentsState {
  agents: Agent[];
  setAgents: (agents: Agent[]) => void;
}

export const useAgentsStore = create<AgentsState>((set) => ({
  agents: [],
  setAgents: (agents) => set({ agents }),
}));
