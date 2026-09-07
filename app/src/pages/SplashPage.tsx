import { useMutation, useQuery } from "@tanstack/react-query";
import { motion } from "framer-motion";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { GhuiChip } from "../components/GhuiChip";
import { FieldsetPanel } from "../components/FieldsetPanel";
import styles from "./SplashPage.module.css";

export function SplashPage() {
  const nav = useNavigate();
  const [params] = useSearchParams();
  const holdLogin = params.get("screenshot") === "login";
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

  useEffect(() => {
    if (holdLogin) return;
    if (gh?.authenticated) nav("/splash/staging", { replace: true });
  }, [gh?.authenticated, nav, holdLogin]);

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className={styles.page}
    >
      <h1 className={styles.title}>cockpit</h1>
      <p className={styles.subtitle}>
        GitHub OAuth device-flow · tokens in OS keyring / Stronghold only
      </p>

      <div className={styles.fieldsetWrap}>
        <FieldsetPanel title="auth">
          <div className={styles.authBody}>
            {gh?.authenticated ? (
              <GhuiChip label={`gh ✓ ${gh.user ?? "authenticated"}`} tone="cyan" />
            ) : userCode ? (
              <>
                <GhuiChip label={`code ${userCode}`} tone="yellow" />
                <a className={styles.link} href={verifyUri ?? "https://github.com/login/device"}>
                  {verifyUri}
                </a>
                <p className={styles.hint}>Polling… token stored via gh keyring</p>
              </>
            ) : (
              <button
                type="button"
                className={styles.primaryBtn}
                onClick={() => startDevice.mutate()}
                disabled={startDevice.isPending}
              >
                Start GitHub device flow
              </button>
            )}
          </div>
        </FieldsetPanel>
      </div>

      {health && (
        <GhuiChip
          label={`health ${health.status}`}
          tone={health.status === "green" ? "cyan" : "yellow"}
        />
      )}

      <button
        type="button"
        onClick={() => nav("/splash/staging")}
        disabled={!gh?.authenticated}
        className={styles.enterBtn}
      >
        Enter staging multiview
      </button>
    </motion.div>
  );
}
