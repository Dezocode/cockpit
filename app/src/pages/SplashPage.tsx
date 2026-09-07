import { useMutation, useQuery } from "@tanstack/react-query";
import { motion } from "framer-motion";
import { useNavigate } from "react-router-dom";
import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { GhuiChip } from "../components/GhuiChip";

export function SplashPage() {
  const nav = useNavigate();
  const { data: gh, refetch } = useQuery({ queryKey: ["gh-auth"], queryFn: api.ghAuth });
  const { data: health } = useQuery({ queryKey: ["health"], queryFn: api.health });
  const [deviceCode, setDeviceCode] = useState<string | null>(null);
  const [userCode, setUserCode] = useState<string | null>(null);
  const [verifyUri, setVerifyUri] = useState<string | null>(null);

  const startDevice = useMutation({
    mutationFn: api.deviceStart,
    onSuccess: (d) => {
      setDeviceCode(d.device_code);
      setUserCode(d.user_code);
      setVerifyUri(d.verification_uri);
    },
  });

  useEffect(() => {
    if (!deviceCode || gh?.authenticated) return;
    const id = window.setInterval(async () => {
      const poll = await api.devicePoll(deviceCode);
      if (poll.status === "complete") {
        refetch();
        window.clearInterval(id);
      }
    }, 5000);
    return () => window.clearInterval(id);
  }, [deviceCode, gh?.authenticated, refetch]);

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="flex min-h-screen flex-col items-center justify-center gap-6 bg-[#0b0f14] p-8"
    >
      <h1 className="text-3xl font-bold text-cyan-300">cockpit</h1>
      <p className="max-w-md text-center text-slate-400">
        GitHub OAuth device-flow · tokens in OS keyring / Stronghold only
      </p>

      <div className="flex flex-col items-center gap-3 rounded-lg border border-slate-700 bg-slate-900/60 p-6">
        {gh?.authenticated ? (
          <GhuiChip label={`gh ✓ ${gh.user ?? "authenticated"}`} tone="cyan" />
        ) : userCode ? (
          <>
            <GhuiChip label={`code ${userCode}`} tone="yellow" />
            <a className="text-sm text-cyan-400 underline" href={verifyUri ?? "https://github.com/login/device"}>
              {verifyUri}
            </a>
            <p className="text-xs text-slate-500">Polling… token stored via gh keyring</p>
          </>
        ) : (
          <button
            type="button"
            className="rounded bg-cyan-700 px-4 py-2 text-sm"
            onClick={() => startDevice.mutate()}
            disabled={startDevice.isPending}
          >
            Start GitHub device flow
          </button>
        )}
      </div>

      {health && (
        <GhuiChip label={`health ${health.status}`} tone={health.status === "green" ? "cyan" : "yellow"} />
      )}

      <button
        type="button"
        onClick={() => nav("/workspace")}
        disabled={!gh?.authenticated}
        className="rounded bg-cyan-600 px-6 py-2 text-sm disabled:opacity-40"
      >
        Enter workspace
      </button>
    </motion.div>
  );
}
