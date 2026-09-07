import { useCallback, useEffect, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import {
  DockviewReact,
  DockviewReadyEvent,
  IDockviewPanelProps,
  DockviewApi,
} from "dockview-react";
import "dockview-react/dist/styles/dockview.css";
import { AgentBar, chipToPage } from "./AgentBar";
import { FieldsetPanel } from "./FieldsetPanel";
import { ThemeSwitcher } from "./ThemeSwitcher";
import { AgentsPanelContent } from "./panels/AgentsPanelContent";
import { ComputersPanelContent } from "./panels/ComputersPanelContent";
import { FilesPanelContent } from "./panels/FilesPanelContent";
import { GraphPanelContent } from "./panels/GraphPanelContent";
import { useCockpitStore } from "../stores/cockpit";
import {
  loadLayoutV3,
  saveLayoutV3,
  newPanelId,
  type StagingPanelType,
  type StagingPanelState,
} from "../lib/layout-v3";
import { loadTheme, saveTheme, applyTheme, type CockpitTheme } from "../lib/theme";
import type { AgentBarChip } from "../lib/types";
import styles from "./StagingMultiview.module.css";

const PALETTE: StagingPanelType[] = ["AGENTS", "COMPUTERS", "FILES"];

function panelTitle(type: StagingPanelType): string {
  return type;
}

function PanelBody({ type }: { type: StagingPanelType }) {
  switch (type) {
    case "AGENTS":
      return <AgentsPanelContent />;
    case "COMPUTERS":
      return <ComputersPanelContent />;
    case "FILES":
      return <FilesPanelContent />;
    case "GRAPH":
      return <GraphPanelContent />;
    default:
      return null;
  }
}

function StagingPanel(props: IDockviewPanelProps<{ panelType: StagingPanelType }>) {
  const type = props.params.panelType;
  return (
    <div className={styles.panelWrap}>
      <FieldsetPanel title={panelTitle(type)}>
        <PanelBody type={type} />
      </FieldsetPanel>
    </div>
  );
}

const components = { staging: StagingPanel };

export function StagingMultiview() {
  const [searchParams] = useSearchParams();
  const apiRef = useRef<DockviewApi | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const readyRef = useRef(false);
  const [theme, setTheme] = useState<CockpitTheme>(loadTheme);
  const [panelCount, setPanelCount] = useState(0);
  const [fullscreen, setFullscreen] = useState(false);
  const setActivePage = useCockpitStore((s) => s.setActivePage);
  const activePage = useCockpitStore((s) => s.activePage);

  const syncCount = useCallback((api: DockviewApi) => {
    setPanelCount(api.panels.length);
  }, []);

  const persistLayout = useCallback(() => {
    const api = apiRef.current;
    if (!api) return;
    const panels: StagingPanelState[] = api.panels.map((p) => ({
      id: p.id,
      type: (p.params as { panelType: StagingPanelType }).panelType,
    }));
    saveLayoutV3({
      version: 3,
      panels,
      serialized: JSON.stringify(api.toJSON()),
    });
    syncCount(api);
  }, [syncCount]);

  const addPanel = useCallback(
    (type: StagingPanelType, id?: string) => {
      const api = apiRef.current;
      if (!api || !readyRef.current) return;
      const panelId = id ?? newPanelId(type);
      const existing = api.getPanel(panelId);
      if (existing) {
        existing.api.setActive();
        return;
      }
      const refs = api.panels;
      api.addPanel({
        id: panelId,
        component: "staging",
        title: panelTitle(type),
        params: { panelType: type },
        position: refs.length
          ? { referencePanel: refs[refs.length - 1].id, direction: "right" }
          : undefined,
      });
      persistLayout();
    },
    [persistLayout],
  );

  const demoMode = searchParams.get("demo");
  const resetLayout = searchParams.get("reset") === "1";
  const themeParam = searchParams.get("theme") as CockpitTheme | null;

  useEffect(() => {
    if (resetLayout) localStorage.removeItem("cockpit.layout.v3");
  }, [resetLayout]);

  useEffect(() => {
    if (demoMode === "theme-ghui-cyan" || themeParam === "ghui-cyan") {
      saveTheme("ghui-cyan");
      applyTheme("ghui-cyan");
      setTheme("ghui-cyan");
    }
  }, [demoMode, themeParam]);

  const onReady = useCallback(
    (event: DockviewReadyEvent) => {
      apiRef.current = event.api;
      readyRef.current = true;
      const saved = resetLayout ? { version: 3 as const, panels: [] } : loadLayoutV3();
      let restored = false;
      if (!resetLayout && saved.serialized) {
        try {
          event.api.fromJSON(JSON.parse(saved.serialized));
          restored = event.api.panels.length > 0;
        } catch {
          /* fall through */
        }
      }
      if (!restored && !demoMode) {
        saved.panels.forEach((p) => {
          event.api.addPanel({
            id: p.id,
            component: "staging",
            title: panelTitle(p.type),
            params: { panelType: p.type },
            position: event.api.panels.length
              ? {
                  referencePanel: event.api.panels[event.api.panels.length - 1].id,
                  direction: "right",
                }
              : undefined,
          });
        });
      }
      syncCount(event.api);
      event.api.onDidLayoutChange(() => persistLayout());
      event.api.onDidRemovePanel(() => persistLayout());

      if (demoMode === "3panels") {
        ["AGENTS", "COMPUTERS", "FILES"].forEach((t) => {
          event.api.addPanel({
            id: newPanelId(t as StagingPanelType),
            component: "staging",
            title: t,
            params: { panelType: t as StagingPanelType },
            position: event.api.panels.length
              ? { referencePanel: event.api.panels[event.api.panels.length - 1].id, direction: "right" }
              : undefined,
          });
        });
        syncCount(event.api);
      } else if (demoMode === "graph") {
        saveTheme("ghui-cyan");
        applyTheme("ghui-cyan");
        setTheme("ghui-cyan");
        ["FILES", "GRAPH"].forEach((t) => {
          event.api.addPanel({
            id: newPanelId(t as StagingPanelType),
            component: "staging",
            title: t,
            params: { panelType: t as StagingPanelType },
            position: event.api.panels.length
              ? { referencePanel: event.api.panels[event.api.panels.length - 1].id, direction: "right" }
              : undefined,
          });
        });
        syncCount(event.api);
      } else if (demoMode === "fullscreen") {
        saveTheme("ghui-cyan");
        applyTheme("ghui-cyan");
        setTheme("ghui-cyan");
        ["FILES", "GRAPH"].forEach((t) => {
          event.api.addPanel({
            id: newPanelId(t as StagingPanelType),
            component: "staging",
            title: t,
            params: { panelType: t as StagingPanelType },
            position: event.api.panels.length
              ? { referencePanel: event.api.panels[event.api.panels.length - 1].id, direction: "right" }
              : undefined,
          });
        });
        containerRef.current?.setAttribute("data-screenshot-fullscreen", "1");
        setFullscreen(true);
        syncCount(event.api);
      } else if (demoMode === "focus") {
        saveTheme("ghui-cyan");
        applyTheme("ghui-cyan");
        setTheme("ghui-cyan");
        event.api.addPanel({
          id: newPanelId("FILES"),
          component: "staging",
          title: "FILES",
          params: { panelType: "FILES" },
        });
        syncCount(event.api);
        window.setTimeout(() => {
          document
            .querySelector<HTMLButtonElement>('[aria-label="Theme switcher"] button[data-theme="ghui-cyan"]')
            ?.focus();
        }, 400);
      } else if (demoMode === "theme-ghui-cyan") {
        saveTheme("ghui-cyan");
        applyTheme("ghui-cyan");
        setTheme("ghui-cyan");
        event.api.addPanel({
          id: newPanelId("FILES"),
          component: "staging",
          title: "FILES",
          params: { panelType: "FILES" },
        });
        syncCount(event.api);
      }
    },
    [persistLayout, syncCount, demoMode, resetLayout],
  );

  const onDragStart = (e: React.DragEvent, type: StagingPanelType) => {
    e.dataTransfer.setData("application/cockpit-panel", type);
    e.dataTransfer.effectAllowed = "copy";
  };

  const onDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const type = e.dataTransfer.getData("application/cockpit-panel") as StagingPanelType;
    if (PALETTE.includes(type)) addPanel(type);
  };

  const onDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = "copy";
  };

  const toggleFullscreen = async () => {
    const el = containerRef.current;
    if (!el) return;
    if (!document.fullscreenElement) {
      await el.requestFullscreen();
      setFullscreen(true);
    } else {
      await document.exitFullscreen();
      setFullscreen(false);
    }
  };

  useEffect(() => {
    const onFs = () => setFullscreen(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", onFs);
    return () => document.removeEventListener("fullscreenchange", onFs);
  }, []);

  const onBarChip = (chip: AgentBarChip) => {
    if (chip === "RESTART") {
      window.location.reload();
      return;
    }
    const page = chipToPage(chip);
    if (page) {
      setActivePage(page);
      if (page === "FILES") addPanel("FILES");
      if (page === "COMPUTERS") addPanel("COMPUTERS");
      if (page === "MEMORY") addPanel("AGENTS");
      if (page === "SETUP") addPanel("FILES");
    }
  };

  const clearLayout = () => {
    localStorage.removeItem("cockpit.layout.v3");
    window.location.reload();
  };

  return (
    <div ref={containerRef} className={styles.staging} data-fullscreen={fullscreen || undefined}>
      <AgentBar onChip={onBarChip} providerLabel="AGENT" />
      <div className={styles.toolbar}>
        <span className={styles.brand}>staging multiview</span>
        <ThemeSwitcher value={theme} onChange={setTheme} compact />
        <button type="button" className={styles.btn} onClick={() => addPanel("GRAPH")}>
          + graph
        </button>
        <button
          type="button"
          className={`${styles.btn} ${fullscreen ? styles.btnActive : ""}`}
          onClick={toggleFullscreen}
        >
          {fullscreen ? "exit fullscreen" : "fullscreen"}
        </button>
        <button type="button" className={styles.btn} onClick={clearLayout}>
          reset layout
        </button>
      </div>
      <div className={styles.body}>
        <aside className={styles.paletteWrap} aria-label="Panel palette">
          <FieldsetPanel title="palette">
            <div className={styles.paletteInner}>
              {PALETTE.map((type) => (
                <div
                  key={type}
                  className={styles.paletteItem}
                  draggable
                  onDragStart={(e) => onDragStart(e, type)}
                  onDoubleClick={() => addPanel(type)}
                >
                  {type}
                </div>
              ))}
            </div>
          </FieldsetPanel>
        </aside>
        <div className={styles.canvas} onDrop={onDrop} onDragOver={onDragOver}>
          {panelCount === 0 && (
            <div className={styles.canvasEmpty}>Drop Agents · Computers · Files here</div>
          )}
          <div className={`dockview-theme-cockpit ${styles.dockHost}`}>
            <DockviewReact components={components} onReady={onReady} className="h-full w-full" />
          </div>
        </div>
      </div>
      <div className={styles.footer}>
        active: {activePage} · panels: {panelCount} · layout: cockpit.layout.v3 · Foot size-owning · Funnel OFF · Serve OFF
      </div>
    </div>
  );
}
