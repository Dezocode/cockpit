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
