export interface ComputerRow {
  id: string;
  name: string;
  status?: string;
  latencyMs?: number;
  geo?: { lat: number; lon: number };
  geoSource?: 'explicit' | 'env' | 'tz';
  tz?: string;
  role?: string;
  tailnet?: boolean;
}

export interface ComputersPayload {
  computers: ComputerRow[];
  offlineThresholdMs: number;
  hermesNote?: string;
}

export interface PlacedNode {
  id: string;
  name: string;
  latencyMs: number;
  online: boolean;
  colorToken: 'accent' | 'active';
  geo: { lat: number; lon: number };
  geoSource: string;
}

export declare function mapFleetRoster(args: {
  payload: ComputersPayload;
  tzCentroids?: Record<string, { lat: number; lon: number }>;
  localTz?: string;
  nodeGeoEnv?: string;
}): {
  placed: PlacedNode[];
  unplaced: Array<{ id: string; name: string; latencyMs: number; online: boolean }>;
  local: PlacedNode | null;
  offlineThresholdMs: number;
};

export declare function assertComputersPayload(payload: unknown): ComputersPayload;

export interface FleetArc {
  id: string;
  fromId: string;
  toId: string;
  from: { lat: number; lon: number };
  to: { lat: number; lon: number };
  midpoint: { lat: number; lon: number };
  latencyMs: number;
  label: string;
  colorToken: 'accent' | 'active';
}

export declare function computeFleetArcs(mapped: {
  placed: PlacedNode[];
  local: PlacedNode | null;
}): FleetArc[];

export declare function geodesicMidpoint(
  a: { lat: number; lon: number },
  b: { lat: number; lon: number },
): { lat: number; lon: number };

export declare function clampLineWidth(
  requested: number,
  range: ArrayLike<number> | null | undefined,
): number;
