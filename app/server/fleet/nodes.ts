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

function parseNodeGeo(raw: string | undefined): { lat: number; lon: number } | undefined {
  const m = raw?.trim().match(/^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$/);
  if (!m) return undefined;
  const lat = Number(m[1]);
  const lon = Number(m[2]);
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return undefined;
  return { lat, lon };
}

function fixtureComputers() {
  const localTz = Intl.DateTimeFormat().resolvedOptions().timeZone;
  const computers: ComputerRow[] = [
    { id: "local", name: "Local Dev", status: "online", latencyMs: 0, tailnet: false, tz: localTz },
    { id: "hermes", name: "Hermes Deck", status: "online", latencyMs: 12, tailnet: true, role: "hermes" },
    { id: "hostinger", name: "Hostinger VPS", status: "online", latencyMs: 42, tailnet: true },
    { id: "omarchy", name: "Omarchy Pad", status: "online", latencyMs: 8, tailnet: false },
  ];
  // Placement ladder for the local node (keyless, no network): explicit geo >
  // COCKPIT_NODE_GEO > IANA tz centroid (tzdata zone1970.tab) > unplaced.
  // Zones without a zone1970.tab entry (e.g. "UTC") stay unplaced: never invent coordinates.
  const local = computers.find((c) => c.id === "local");
  if (local && !local.geo) {
    const envGeo = parseNodeGeo(process.env.COCKPIT_NODE_GEO);
    const centroid = local.tz ? tzCentroids[local.tz] : undefined;
    if (envGeo) {
      local.geo = envGeo;
      local.geoSource = "env";
    } else if (centroid) {
      local.geo = { lat: centroid.lat, lon: centroid.lon };
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
