import { useRef, useCallback, useEffect } from "react";
import { useLocation } from "react-router-dom";
import {
  DockviewReact,
  DockviewReadyEvent,
  IDockviewPanelProps,
  DockviewApi,
} from "dockview-react";
import "dockview-react/dist/styles/dockview.css";
import { Group, Panel, Separator } from "react-resizable-panels";
import { PAGE_IDS, type PageId, type AgentBarChip } from "../lib/types";
import { useCockpitStore } from "../stores/cockpit";
import { AgentBar, chipToPage } from "./AgentBar";
import { FieldsetPanel } from "./FieldsetPanel";
import {
  AgentPage,
  FilesPage,
  DiffPage,
  MapPage,
  SetupPage,
  PrsPage,
  BenchPage,
} from "../pages/static-pages";
import { MemoryPage, ComputersPage } from "../pages/data-pages";
import styles from "./CockpitShell.module.css";

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
    <div className={styles.panelWrap}>
      <FieldsetPanel title={id}>
        <Page />
      </FieldsetPanel>
    </div>
  );
}

const components = { default: PagePanel };

export function CockpitShell() {
  const location = useLocation();
  const setActivePage = useCockpitStore((s) => s.setActivePage);
  const activePage = useCockpitStore((s) => s.activePage);
  const apiRef = useRef<DockviewApi | null>(null);

  const focusPage = useCallback(
    (id: PageId) => {
      setActivePage(id);
      apiRef.current?.getPanel(id)?.api.setActive();
    },
    [setActivePage],
  );

  const onReady = useCallback(
    (event: DockviewReadyEvent) => {
      apiRef.current = event.api;
      PAGE_IDS.forEach((id, i) => {
        event.api.addPanel({
          id,
          component: "default",
          title: id,
          position: i === 0 ? undefined : { referencePanel: PAGE_IDS[i - 1], direction: "right" },
        });
      });
      event.api.onDidActivePanelChange(() => {
        const active = event.api.activePanel;
        if (active) setActivePage(active.id as PageId);
      });
    },
    [setActivePage],
  );

  useEffect(() => {
    const hash = location.hash.replace("#", "") as PageId | "MODEL";
    if (hash === "MODEL") {
      focusPage("COMPUTERS");
      return;
    }
    if (hash && PAGE_IDS.includes(hash as PageId)) {
      focusPage(hash as PageId);
    }
  }, [location.hash, focusPage]);

  const onBarChip = (chip: AgentBarChip) => {
    if (chip === "RESTART") {
      window.location.reload();
      return;
    }
    const page = chipToPage(chip);
    if (page) focusPage(page);
  };

  return (
    <div className={styles.shell}>
      <AgentBar onChip={onBarChip} providerLabel="AGENT" />
      <Group orientation="vertical" className={styles.main}>
        <Panel defaultSize={92} minSize={50}>
          <div className={`dockview-theme-cockpit ${styles.dock}`}>
            <DockviewReact components={components} onReady={onReady} className="h-full w-full" />
          </div>
        </Panel>
        <Separator className={styles.separator} />
        <Panel defaultSize={8} minSize={4}>
          <div className={styles.footer}>
            active: {activePage} · Foot size-owning on dezohost · Funnel OFF · Serve OFF
          </div>
        </Panel>
      </Group>
    </div>
  );
}
