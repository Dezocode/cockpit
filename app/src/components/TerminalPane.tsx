import { useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { WebLinksAddon } from "@xterm/addon-web-links";
import "@xterm/xterm/css/xterm.css";
import { api, ptyWebSocketUrl, authApi, githubLoginUrl } from "../lib/api";
import { GhuiChip } from "./GhuiChip";

interface TerminalPaneProps {
  agentId?: string;
}

/** Web PTY via ws. Foot/Ghostty = shell-out registry (not embedded in xterm). */
export function TerminalPane({ agentId }: TerminalPaneProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [shellOut, setShellOut] = useState<string | null>(null);
  const { data: emulators } = useQuery({ queryKey: ["emulators"], queryFn: api.emulators });
  const { data: me } = useQuery({ queryKey: ["auth-me"], queryFn: authApi.me });

  useEffect(() => {
    if (!ref.current || !me?.authenticated || !me?.terminal) return;
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

    term.writeln("\x1b[36mcockpit\x1b[0m web PTY (xterm6)");
    term.writeln("\x1b[33mFoot/Ghostty: shell-out registry only — not fake-attached here\x1b[0m");

    let ws: WebSocket | null = null;
    try {
      // Session cookie rides the WS upgrade automatically (same-origin).
      // agent= is audit-only: agents act inside the owning user's session.
      const wsUrl = agentId ? `${ptyWebSocketUrl()}?agent=${encodeURIComponent(agentId)}` : ptyWebSocketUrl();
      ws = new WebSocket(wsUrl);
      ws.onopen = () => term.writeln("\x1b[32mPTY ws connected\x1b[0m");
      ws.onclose = (ev) => {
        if (ev.code === 4401) term.writeln("\x1b[31mterminal: session not authorized\x1b[0m");
      };
      ws.onmessage = (ev) => {
        try {
          const msg = JSON.parse(String(ev.data)) as { type: string; data?: string };
          if (msg.type === "data" && msg.data) term.write(msg.data);
        } catch {
          term.write(String(ev.data));
        }
      };
      ws.onerror = () => term.writeln("\x1b[33mPTY offline — cockpit-web\x1b[0m");
      term.onData((d) => ws?.readyState === WebSocket.OPEN && ws.send(JSON.stringify({ type: "input", data: d })));
    } catch {
      term.writeln("\x1b[33mPTY unavailable\x1b[0m");
    }

    const ro = new ResizeObserver(() => fit.fit());
    ro.observe(ref.current);
    return () => {
      ro.disconnect();
      ws?.close();
      term.dispose();
    };
  }, [agentId, me?.authenticated, me?.terminal]);

  if (!me?.authenticated) {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-3 p-4">
        <div className="text-sm text-slate-300">Terminal is locked</div>
        <a
          href={githubLoginUrl}
          className="rounded border border-slate-700 px-3 py-1 text-sm text-slate-200"
        >
          Sign in with GitHub
        </a>
      </div>
    );
  }
  if (!me?.terminal) {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-2 p-4">
        <div className="text-sm text-slate-300">Signed in as {me?.login} — no terminal access</div>
        <button
          onClick={() => authApi.logout().then(() => window.location.reload())}
          className="rounded border border-slate-700 px-3 py-1 text-sm text-slate-200"
        >
          Sign out
        </button>
      </div>
    );
  }

  const launchShellOut = (id: string) => {
    setShellOut(id);
    api.shellOut(id).catch(() => setShellOut(`${id}: launch via TUI/Foot (dezohost socket)`));
  };

  return (
    <div className="flex h-full flex-col">
      <div className="flex gap-1 border-b border-slate-800 p-1">
        {(emulators?.registry ?? []).map((e) => (
          <GhuiChip
            key={e.id}
            label={e.sizeOwning ? `${e.label} · size-owning` : e.label}
            tone={e.sizeOwning ? "cyan" : "yellow"}
            onClick={() => launchShellOut(e.id)}
          />
        ))}
        {shellOut && <span className="text-xs text-slate-400">{shellOut}</span>}
      </div>
      <div ref={ref} className="min-h-0 flex-1 p-1" />
    </div>
  );
}
