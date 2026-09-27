import { Hono } from "hono";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const tzCentroids = JSON.parse(
  readFileSync(join(__dirname, "tz-centroids.json"), "utf8"),
) as Record<string, { lat: number; lon: number }>;

type ComputerRow = {
  id: string;
  name: string;
  status: string;
  latencyMs: number;
  tailnet?: boolean;
  role?: string;
  tz?: string;
  geo?: { lat: number; lon: number };
  geoSource?: "explicit" | "env" | "tz";
};

function fixtureComputers() {
  const localTz = Intl.DateTimeFormat().resolvedOptions().timeZone;
  const computers: ComputerRow[] = [
    { id: "local", name: "Local Dev", status: "online", latencyMs: 0, tailnet: false, tz: localTz },
    { id: "hermes", name: "Hermes Deck", status: "online", latencyMs: 12, tailnet: true, role: "hermes" },
    { id: "hostinger", name: "Hostinger VPS", status: "online", latencyMs: 42, tailnet: true },
    { id: "omarchy", name: "Omarchy Pad", status: "online", latencyMs: 8, tailnet: false },
  ];
  const nodeGeo = process.env.COCKPIT_NODE_GEO?.trim();
  const local = computers.find((c) => c.id === "local");
  if (local && nodeGeo) {
    const m = nodeGeo.match(/^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$/);
    if (m) {
      local.geo = { lat: Number(m[1]), lon: Number(m[2]) };
      local.geoSource = "env";
    }
  } else if (local) {
    const centroid = tzCentroids[localTz] ?? (localTz === "UTC" ? { lat: 0, lon: 0 } : undefined);
    if (centroid) {
      local.geo = centroid;
      local.geoSource = "tz";
    }
  }
  return {
    computers,
    offlineThresholdMs: 3000,
    hermesNote: "Deck receipt / COMPUTERS node — NOT an AGENT provider",
  };
}

export const fleetNodesApp = new Hono();

fleetNodesApp.get("/api/computers", (c) => c.json(fixtureComputers()));
