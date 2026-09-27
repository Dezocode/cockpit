export type MapSourceEntry = {
  descriptor: { id: string; remoteHost?: string | null; label?: string };
  available: boolean;
  imagery: () => unknown;
  terrain: { create: (opts?: unknown) => Promise<{ provider: unknown }> };
  credit?: string;
};

export function createDefaultMapSources(options?: unknown): {
  defaultId: string;
  unknownId: string;
  recoveryId: string | null;
  state: { hasCesiumIonToken: boolean };
  sources: MapSourceEntry[];
};
export function findMapSource(
  sources: ReturnType<typeof createDefaultMapSources>,
  id: string,
): MapSourceEntry | null;
export function resolveStackId(sources: ReturnType<typeof createDefaultMapSources>, requestedId: string): string;
