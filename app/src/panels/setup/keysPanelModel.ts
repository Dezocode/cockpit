// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/keySetup.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: pure helpers only (chip label + collect updates).

/** Chip label: POWER UP · N KEYS WAITING / POWERED UP */
export function keySetupChipLabel(setCount: number, total: number): string {
  const waiting = Math.max(0, total - setCount);
  if (waiting <= 0) return "POWERED UP";
  return `POWER UP · ${waiting} KEY${waiting === 1 ? "" : "S"} WAITING`;
}

/** Collect non-empty password-field values into {ENV_VAR: value} (or null to remove). */
export function collectKeyUpdates(
  drafts: Record<string, string>,
  removals: string[] = [],
): Record<string, string | null> {
  const out: Record<string, string | null> = {};
  for (const [name, raw] of Object.entries(drafts)) {
    const value = String(raw ?? "").trim();
    if (value) out[name] = value;
  }
  for (const name of removals) out[name] = null;
  return out;
}
