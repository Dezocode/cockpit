import { useEffect, useRef } from "react";
import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { WebLinksAddon } from "@xterm/addon-web-links";
import "@xterm/xterm/css/xterm.css";
import { ptyWebSocketUrl } from "../lib/api";

interface TerminalPaneProps {
  agentId?: string;
}

export function TerminalPane({ agentId }: TerminalPaneProps) {
  const ref = useRef<HTMLDivElement>(null);
  const termRef = useRef<Terminal | null>(null);

  useEffect(() => {
    if (!ref.current) return;
    const term = new Terminal({
      cursorBlink: true,
      fontFamily: "JetBrains Mono, monospace",
      theme: { background: "#0b0f14", foreground: "#e2e8f0", cursor: "#22d3ee" },
    });
    const fit = new FitAddon();
    term.loadAddon(fit);
    term.loadAddon(new WebLinksAddon());
    term.open(ref.current);
    fit.fit();
    termRef.current = term;

    term.writeln(`\x1b[36mcockpit\x1b[0m terminal ${agentId ? `[${agentId}]` : ""}`);
    term.writeln("Connecting PTY…");

    let ws: WebSocket | null = null;
    try {
      ws = new WebSocket(ptyWebSocketUrl());
      ws.onopen = () => {
        term.writeln("\x1b[32mPTY connected\x1b[0m");
        ws?.send(JSON.stringify({ type: "input", data: "echo cockpit pty ready\r" }));
      };
      ws.onmessage = (ev) => {
        try {
          const msg = JSON.parse(String(ev.data)) as { type: string; data?: string };
          if (msg.type === "data" && msg.data) term.write(msg.data);
        } catch {
          term.write(String(ev.data));
        }
      };
      ws.onerror = () => term.writeln("\x1b[33mPTY ws offline — start: pnpm dev:web\x1b[0m");
    } catch {
      term.writeln("\x1b[33mPTY unavailable in this context\x1b[0m");
    }

    term.onData((data) => ws?.readyState === WebSocket.OPEN && ws.send(JSON.stringify({ type: "input", data })));

    const ro = new ResizeObserver(() => {
      fit.fit();
      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: "resize", cols: term.cols, rows: term.rows }));
      }
    });
    ro.observe(ref.current);

    return () => {
      ro.disconnect();
      ws?.close();
      term.dispose();
    };
  }, [agentId]);

  return <div ref={ref} className="h-full w-full p-1" />;
}
