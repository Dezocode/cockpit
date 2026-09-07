import { useRef, useCallback } from "react";
import {
  DockviewReact,
  DockviewReadyEvent,
  IDockviewPanelProps,
  DockviewApi,
} from "dockview";
import "dockview/dist/styles/dockview.css";
import { PAGE_IDS, type PageId } from "../lib/types";
import { useCockpitStore } from "../stores/cockpit";
import { GhuiChip } from "./GhuiChip";
import {
  AgentPage,
  FilesPage,
  DiffPage,
  MapPage,
  SetupPage,
  PrsPage,
  BenchPage,
  ModelsPage,
} from "../pages/static-pages";
import { MemoryPage, ComputersPage } from "../pages/data-pages";

function panelFactory(id: PageId) {
  switch (id) {
    case "AGENT":
      return AgentPage;
    case "FILES":
      return FilesPage;
    case "DIFF":
      return DiffPage;
    case "MEMORY":
      return MemoryPage;
    case "COMPUTERS":
      return ComputersPage;
    case "MODELS":
      return ModelsPage;
    case "BENCH":
      return BenchPage;
    case "PRS":
      return PrsPage;
    case "SETUP":
      return SetupPage;
    case "MAP":
      return MapPage;
    default:
      return AgentPage;
  }
}

function PagePanel(props: IDockviewPanelProps<{ title: string }>) {
  const id = props.api.id as PageId;
  const Page = panelFactory(id);
  return (
    <div className="h-full overflow-hidden bg-[#0b0f14]">
      <Page />
    </div>
  );
}

const components = { default: PagePanel };

export function CockpitShell() {
  const setActivePage = useCockpitStore((s) => s.setActivePage);
  const activePage = useCockpitStore((s) => s.activePage);
  const apiRef = useRef<DockviewApi | null>(null);

  const onReady = useCallback((event: DockviewReadyEvent) => {
    apiRef.current = event.api;
    PAGE_IDS.forEach((id, i) => {
      event.api.addPanel({
        id,
        component: "default",
        title: id,
        position: i === 0 ? undefined : { referencePanel: PAGE_IDS[i - 1], direction: "right" },
      });
    });
    event.api.onDidActivePanelChange((panel) => {
      if (panel) setActivePage(panel.id as PageId);
    });
  }, [setActivePage]);

  const focusPage = (id: PageId) => {
    setActivePage(id);
    apiRef.current?.getPanel(id)?.api.setActive();
  };

  return (
    <div className="flex h-screen flex-col">
      <nav className="flex flex-wrap items-center gap-2 border-b border-slate-700 bg-[#121820] px-3 py-2">
        <span className="mr-2 font-bold text-cyan-300">cockpit</span>
        {PAGE_IDS.map((id) => (
          <GhuiChip
            key={id}
            label={id}
            tone={activePage === id ? "cyan" : "yellow"}
            active={activePage === id}
            onClick={() => focusPage(id)}
          />
        ))}
      </nav>
      <div className="dockview-theme-cockpit flex-1">
        <DockviewReact components={components} onReady={onReady} className="h-full w-full" />
      </div>
    </div>
  );
}
