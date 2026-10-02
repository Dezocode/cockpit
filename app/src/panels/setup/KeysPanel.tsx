// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/keySetup.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: React KeysPanel; --cockpit-* tokens; removes self when /api/setup/status unreachable; ?setup=1.
import { useCallback, useEffect, useState } from "react";
import { collectKeyUpdates, keySetupChipLabel } from "./keysPanelModel";
import styles from "./KeysPanel.module.css";

type KeyRow = {
  id: string;
  title: string;
  unlocks: string;
  getUrl: string;
  envVars: string[];
  tier: string;
  set: boolean;
  managed?: "file" | "external" | null;
};

type StatusPayload = {
  keys: KeyRow[];
  setCount: number;
  total: number;
  store?: string;
};

export function KeysPanel() {
  const [status, setStatus] = useState<StatusPayload | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [error, setError] = useState("");
  const [editing, setEditing] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const res = await fetch("/api/setup/status", { credentials: "same-origin" });
      if (!res.ok) {
        // Drain the body. An unread 401 leaves the browser request open, and
        // Playwright's networkidle (t384u /workspace) never arrives.
        await res.text().catch(() => {});
        setUnavailable(true);
        setStatus(null);
        return;
      }
      const body = (await res.json()) as StatusPayload;
      setStatus(body);
      setUnavailable(false);
      setError("");
    } catch {
      setUnavailable(true);
      setStatus(null);
    }
  }, []);

  useEffect(() => {
    void load();
    const params = new URLSearchParams(window.location.search);
    if (params.get("setup") === "1") {
      document.getElementById("cockpit-keys-panel")?.scrollIntoView({ behavior: "smooth" });
    }
  }, [load]);

  useEffect(() => {
    return () => {
      setDraft("");
    };
  }, []);

  if (unavailable) return null;
  if (!status) {
    return (
      <div className={styles.root} id="cockpit-keys-panel" data-testid="keys-panel-loading">
        <p className={styles.banner}>Loading KEYS…</p>
      </div>
    );
  }

  const chip = keySetupChipLabel(status.setCount, status.total);

  async function save(row: KeyRow) {
    setBusy(true);
    setError("");
    try {
      const updates = collectKeyUpdates({ [row.envVars[0]]: draft });
      const res = await fetch("/api/setup/keys", {
        method: "POST",
        credentials: "same-origin",
        headers: { "Content-Type": "application/json", Origin: window.location.origin },
        body: JSON.stringify(updates),
      });
      const body = (await res.json().catch(() => ({}))) as { error?: string; status?: StatusPayload };
      if (!res.ok) {
        setError(body.error || `save failed (${res.status})`);
        return;
      }
      setDraft("");
      setEditing(null);
      if (body.status) setStatus(body.status);
      else await load();
    } finally {
      setBusy(false);
    }
  }

  async function remove(row: KeyRow) {
    if (row.managed === "external") return;
    setBusy(true);
    setError("");
    try {
      const updates: Record<string, null> = {};
      for (const name of row.envVars) updates[name] = null;
      const res = await fetch("/api/setup/keys", {
        method: "POST",
        credentials: "same-origin",
        headers: { "Content-Type": "application/json", Origin: window.location.origin },
        body: JSON.stringify(updates),
      });
      const body = (await res.json().catch(() => ({}))) as { error?: string; status?: StatusPayload };
      if (!res.ok) {
        setError(body.error || `remove failed (${res.status})`);
        return;
      }
      if (body.status) setStatus(body.status);
      else await load();
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className={styles.root} id="cockpit-keys-panel" data-testid="keys-panel">
      <fieldset className={styles.fieldset}>
        <legend className={styles.legend}>-KEYS- · {chip}</legend>
        <p className={styles.banner}>
          Cockpit works without keys. Add one to enable a provider. Values never leave this machine —
          the page only ever shows <strong>set ✓</strong>.
        </p>
        {error ? <p className={styles.error}>{error}</p> : null}
        {status.keys.map((row) => (
          <div className={styles.row} key={row.id} data-testid={`keys-row-${row.id}`}>
            <div className={styles.meta}>
              <span className={styles.title}>{row.title}</span>
              <span className={styles.unlocks}>{row.unlocks}</span>
              {row.getUrl ? (
                <a href={row.getUrl} target="_blank" rel="noreferrer">
                  get key
                </a>
              ) : null}
            </div>
            <span
              className={`${styles.chip} ${row.set ? "" : styles.chipMuted}`}
              data-testid={`keys-chip-${row.id}`}
            >
              {row.set ? "set ✓" : "not set"}
            </span>
            <div className={styles.actions}>
              {row.managed === "external" ? (
                <span className={styles.chipMuted}>external</span>
              ) : editing === row.id ? (
                <>
                  <input
                    className={styles.input}
                    type="password"
                    autoComplete="off"
                    value={draft}
                    placeholder="paste key"
                    onChange={(e) => setDraft(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") void save(row);
                      if (e.key === "Escape") {
                        setEditing(null);
                        setDraft("");
                      }
                    }}
                    disabled={busy}
                    data-testid={`keys-input-${row.id}`}
                  />
                  <button
                    type="button"
                    className={`${styles.btn} ${styles.btnPrimary}`}
                    disabled={busy || !draft.trim()}
                    onClick={() => void save(row)}
                  >
                    Save
                  </button>
                  <button
                    type="button"
                    className={styles.btn}
                    disabled={busy}
                    onClick={() => {
                      setEditing(null);
                      setDraft("");
                    }}
                  >
                    Cancel
                  </button>
                </>
              ) : (
                <>
                  <button
                    type="button"
                    className={styles.btn}
                    disabled={busy}
                    onClick={() => {
                      setEditing(row.id);
                      setDraft("");
                    }}
                  >
                    Set
                  </button>
                  {row.set && row.managed === "file" ? (
                    <button
                      type="button"
                      className={styles.btn}
                      disabled={busy}
                      onClick={() => void remove(row)}
                    >
                      Remove
                    </button>
                  ) : null}
                </>
              )}
            </div>
          </div>
        ))}
        <p className={styles.hostingerNote}>
          On Hostinger (behind nginx), set keys over SSH with <code>cockpit keys set</code> — this
          panel refuses proxied requests by design.
        </p>
      </fieldset>
    </div>
  );
}
