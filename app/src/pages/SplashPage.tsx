import { useQuery } from "@tanstack/react-query";
import { motion } from "framer-motion";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api";
import { GhuiChip } from "../components/GhuiChip";

export function SplashPage() {
  const nav = useNavigate();
  const { data: gh, refetch } = useQuery({ queryKey: ["gh-auth"], queryFn: api.ghAuth });
  const { data: health } = useQuery({ queryKey: ["health"], queryFn: api.health });

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="flex min-h-screen flex-col items-center justify-center gap-6 bg-[#0b0f14] p-8"
    >
      <h1 className="text-3xl font-bold text-cyan-300">cockpit</h1>
      <p className="max-w-md text-center text-slate-400">
        Multi-agent terminal IDE · Tauri 2 + React · parallel TUI upgrade
      </p>

      <div className="flex flex-col items-center gap-3 rounded-lg border border-slate-700 bg-slate-900/60 p-6">
        <span className="text-sm text-slate-300">GitHub auth (local state)</span>
        {gh?.authenticated ? (
          <GhuiChip label={`gh ✓ ${gh.user ?? "authenticated"}`} tone="cyan" />
        ) : (
          <>
            <GhuiChip label="gh auth pending" tone="yellow" />
            <code className="rounded bg-black/50 px-3 py-2 text-xs">
              gh auth login -h github.com -p https -w
            </code>
          </>
        )}
        <button
          type="button"
          className="text-xs text-cyan-400 underline"
          onClick={() => refetch()}
        >
          Re-check auth
        </button>
      </div>

      {health && (
        <GhuiChip
          label={`health ${health.status}`}
          tone={health.status === "green" ? "cyan" : "yellow"}
        />
      )}

      <button
        type="button"
        onClick={() => nav("/workspace")}
        disabled={!gh?.authenticated}
        className="rounded bg-cyan-600 px-6 py-2 text-sm disabled:opacity-40"
      >
        Enter workspace
      </button>
      {!gh?.authenticated && (
        <p className="text-xs text-yellow-400/80">Complete gh auth to continue setup</p>
      )}
    </motion.div>
  );
}
