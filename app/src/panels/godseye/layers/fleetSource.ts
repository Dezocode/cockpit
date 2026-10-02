// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/layers/earthquakes/source.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: /api/computers snapshot source (layer contract only).
import { assertComputersPayload } from "./fleetModel.mjs";

export function createFleetSnapshotSource({ fetchImpl = fetch } = {}) {
  return {
    async getSnapshot({ signal }: { signal?: AbortSignal } = {}) {
      const res = await fetchImpl('/api/computers', { signal });
      if (!res.ok) throw new Error(`/api/computers ${res.status}`);
      const payload = await res.json();
      return assertComputersPayload(payload);
    },
  };
}
