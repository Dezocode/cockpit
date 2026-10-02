import { create } from "zustand";
import type { Agent, PageId } from "../lib/types";

interface CockpitState {
  selectedAgentId: string | null;
  selectedComputerId: string | null;
  activePage: PageId;
  accountId: string;
  setSelectedAgent: (id: string | null) => void;
  setSelectedComputer: (id: string | null) => void;
  setActivePage: (page: PageId) => void;
  setAccountId: (id: string) => void;
}

export const useCockpitStore = create<CockpitState>((set) => ({
  selectedAgentId: null,
  selectedComputerId: null,
  activePage: "AGENT",
  accountId: "default",
  setSelectedAgent: (id) => set({ selectedAgentId: id }),
  setSelectedComputer: (id) => set({ selectedComputerId: id }),
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
