const API_BASE =
  typeof window !== "undefined" && window.location.port === "1420"
    ? "http://localhost:8787"
    : "";

async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`);
  if (!res.ok) throw new Error(`${path} ${res.status}`);
  return res.json() as Promise<T>;
}

export const api = {
  health: () => fetchJson<import("./types").HealthResponse>("/api/health"),
  agents: () => fetchJson<import("./types").AgentsResponse>("/api/agents"),
  layout: () => fetchJson<import("./types").LayoutResponse>("/api/layout"),
  ghAuth: () => fetchJson<{ authenticated: boolean; user?: string }>("/api/auth/gh"),
  computers: () =>
    fetchJson<{ computers: Array<{ id: string; name: string; status: string; latencyMs: number }> }>(
      "/api/computers",
    ),
  memory: () =>
    fetchJson<{ entries: Array<{ id: string; title: string; source: string }>; failClosed: boolean }>(
      "/api/memory",
    ),
  emulators: () =>
    fetchJson<{ registry: Array<{ id: string; label: string; sizeOwning: boolean }> }>(
      "/api/emulators",
    ),
};

export function ptyWebSocketUrl(): string {
  const proto = window.location.protocol === "https:" ? "wss:" : "ws:";
  const host =
    window.location.port === "1420"
      ? "localhost:8787"
      : window.location.host;
  return `${proto}//${host}/ws/pty`;
}
