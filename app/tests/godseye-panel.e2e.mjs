#!/usr/bin/env node
import { spawn, execSync } from "node:child_process";
import { chromium } from "playwright";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const appRoot = join(dirname(fileURLToPath(import.meta.url)), "..");

function runProcess(cmd, args, env = {}) {
  const executable = cmd === "node" ? process.execPath : cmd;
  const child = spawn(executable, args, {
    cwd: appRoot,
    env: { ...process.env, ...env },
    stdio: "pipe",
  });
  return child;
}

async function closeGodsEyePanels(page) {
  await page.evaluate(() => {
    const api = window.__cockpitDockviewApi;
    if (!api) return;
    for (const panel of [...api.panels]) {
      const params = panel.params || {};
      if (params.panelType === "GODSEYE") panel.api.close();
    }
  });
}

async function main() {
  try {
    execSync("fuser -k 8787/tcp 2>/dev/null || true", { stdio: "ignore" });
  } catch {
    /* port may already be free */
  }
  const api = runProcess("node", ["dist-server/index.js"], {
    COCKPIT_WEB_HOST: "127.0.0.1",
    COCKPIT_WEB_PORT: "8787",
  });
  const preview = runProcess(
    "pnpm",
    ["exec", "vite", "preview", "--host", "127.0.0.1", "--strictPort", "--port", "1420"],
    {},
  );

  await sleep(3000);

  let nonLoopbackAttempts = 0;
  const browser = await chromium.launch({
    headless: true,
    args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
  });
  const page = await browser.newPage();
  await page.setViewportSize({ width: 1280, height: 900 });
  const errors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(msg.text());
  });
  await page.route("**/*", (route) => {
    const url = new URL(route.request().url());
    if (url.hostname !== "127.0.0.1" && url.hostname !== "localhost") {
      nonLoopbackAttempts += 1;
      return route.abort();
    }
    return route.continue();
  });

  await page.goto("http://127.0.0.1:1420/splash/staging", { waitUntil: "networkidle" });
  await page.getByText("GODSEYE", { exact: true }).dblclick({ timeout: 60000 });
  await page.waitForSelector("[data-testid=godseye-canvas]", { timeout: 60000 });
  await page.waitForFunction(() => window.__cockpitGodsEye?.ready === true, { timeout: 60000 });
  const nodes = await page.evaluate(() => window.__cockpitGodsEye?.entityCount ?? 0);
  if (nodes < 1) {
    console.error(`godseye: expected placed nodes >= 1, got ${nodes}`);
    process.exit(1);
  }

  for (let i = 0; i < 3; i += 1) {
    await closeGodsEyePanels(page);
    await page.waitForSelector("[data-testid=godseye-canvas]", { state: "detached", timeout: 30000 });
    await page.getByText("GODSEYE", { exact: true }).dblclick({ timeout: 60000 });
    await page.waitForFunction(() => window.__cockpitGodsEye?.ready === true, { timeout: 60000 });
  }
  const after = await page.evaluate(() => window.__cockpitGodsEye);

  if (errors.length) {
    console.error("godseye: console errors", errors);
    process.exit(1);
  }
  if (nonLoopbackAttempts !== 0) {
    console.error(`godseye: non-loopback attempts=${nonLoopbackAttempts}`);
    process.exit(1);
  }
  if ((after?.liveViewers ?? 0) > 1) {
    console.error(`godseye: liveViewers=${after?.liveViewers}`);
    process.exit(1);
  }

  await browser.close();
  api.kill("SIGTERM");
  preview.kill("SIGTERM");
  console.log(`godseye: ok (keyless, offline, nodes=${nodes})`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
