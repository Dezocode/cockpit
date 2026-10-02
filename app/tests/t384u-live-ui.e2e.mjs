#!/usr/bin/env node
// t384u live UI (t1127u C9-next). Starts the built dist-server and vite preview
// on ephemeral 127.0.0.1 ports this process owns, screenshots the live SPA, and
// re-reads each PNG. A flat crop fails. Teardown signals only children spawned
// here. Does not start a GitHub device flow.
import { spawn } from "node:child_process";
import { connect, createServer } from "node:net";
import { mkdirSync, statSync } from "node:fs";
import { chromium } from "playwright";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const appRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const HOST = "127.0.0.1";
const shotDir = process.env.T384U_SHOT_DIR;
if (!shotDir) {
  console.error("t384u: FAIL T384U_SHOT_DIR is required");
  process.exit(1);
}
mkdirSync(shotDir, { recursive: true });

const children = [];
let browser = null;

function signalChild(c, sig) {
  if (c.ownGroup && c.exitCode === null && c.signalCode === null) {
    try {
      process.kill(-c.pid, sig);
      return;
    } catch {
      /* group already gone */
    }
  }
  try { c.kill(sig); } catch { /* already exited */ }
}

async function stopChildren() {
  if (browser) await browser.close().catch(() => {});
  await Promise.all(children.map((c) => new Promise((resolve) => {
    c.removeAllListeners("exit");
    if (c.exitCode !== null || c.signalCode !== null) return resolve();
    const hard = setTimeout(() => signalChild(c, "SIGKILL"), 5000);
    c.once("exit", () => { clearTimeout(hard); resolve(); });
    signalChild(c, "SIGTERM");
  })));
}

let failing = false;
function fail(message, extra) {
  if (!failing) {
    failing = true;
    console.error(`t384u: FAIL ${message}`);
    if (extra !== undefined) console.error(typeof extra === "string" ? extra : JSON.stringify(extra, null, 2));
    stopChildren().finally(() => process.exit(1));
  }
  throw new Error(message);
}
function assert(cond, message, extra) {
  if (!cond) fail(message, extra);
}

async function freePorts(n) {
  const servers = await Promise.all(Array.from({ length: n }, () => new Promise((resolve, reject) => {
    const srv = createServer();
    srv.once("error", reject);
    srv.listen(0, HOST, () => resolve(srv));
  })));
  const ports = servers.map((srv) => srv.address().port);
  await Promise.all(servers.map((srv) => new Promise((resolve) => srv.close(resolve))));
  return ports;
}

function tcpOpen(ip, port) {
  return new Promise((resolve) => {
    const sock = connect({ host: ip, port, timeout: 1500 });
    sock.once("connect", () => { sock.destroy(); resolve(true); });
    sock.once("error", () => resolve(false));
    sock.once("timeout", () => { sock.destroy(); resolve(false); });
  });
}

function start(cmd, args, env) {
  const child = spawn(cmd, args, {
    cwd: appRoot,
    env: { ...process.env, ...env },
    stdio: ["ignore", "pipe", "pipe"],
    detached: true,
  });
  child.ownGroup = process.platform !== "win32" && typeof child.pid === "number";
  let log = "";
  child.stdout.on("data", (d) => { log += d; });
  child.stderr.on("data", (d) => { log += d; });
  child.log = () => log;
  children.push(child);
  return child;
}

async function waitHttp(url, timeoutMs = 30000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeoutMs) {
    try {
      const res = await fetch(url);
      if (res.ok) return res;
    } catch { /* not up yet */ }
    await sleep(250);
  }
  throw new Error(`timeout waiting for ${url}`);
}

async function pngCrop(context, png, box) {
  const probe = await context.newPage();
  const file = await probe.evaluate(async ({ b64, box }) => {
    const img = new Image();
    img.src = `data:image/png;base64,${b64}`;
    await img.decode();
    const c = document.createElement("canvas");
    c.width = Math.max(1, Math.round(box.width));
    c.height = Math.max(1, Math.round(box.height));
    const ctx = c.getContext("2d", { willReadFrequently: true });
    ctx.drawImage(
      img,
      Math.round(box.x), Math.round(box.y), c.width, c.height,
      0, 0, c.width, c.height,
    );
    const { data } = ctx.getImageData(0, 0, c.width, c.height);
    const colors = new Set();
    let lit = 0;
    for (let i = 0; i < data.length; i += 4) {
      const r = data[i], g = data[i + 1], b = data[i + 2];
      if (Math.max(r, g, b) > 48) lit += 1;
      colors.add(((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3));
    }
    return {
      image: { w: img.naturalWidth, h: img.naturalHeight },
      crop: { w: c.width, h: c.height },
      litFraction: lit / (data.length / 4),
      distinctColors: colors.size,
    };
  }, { b64: png.toString("base64"), box });
  await probe.close();
  return file;
}

async function shotAndAssert(page, context, path, label, locator) {
  const box = await locator.boundingBox();
  assert(box && box.width > 8 && box.height > 8, `${label}: target has no layout box`, box);
  const png = await page.screenshot({ path });
  const file = await pngCrop(context, png, box);
  const bytes = statSync(path).size;
  assert(file.image.w >= 1200 && file.image.h >= 700, `${label}: PNG is not a full viewport`, file);
  assert(file.crop.w > 8 && file.crop.h > 8, `${label}: PNG crop is empty`, file);
  assert(file.distinctColors >= 4 && file.litFraction > 0.02,
    `${label}: PNG crop is not rendered UI (flat or blank)`, file);
  assert(bytes > 8000, `${label}: PNG file is too small (${bytes})`);
  console.log(
    `t384u: visual ${label} ${path} png=${file.image.w}x${file.image.h} ` +
    `crop=${file.crop.w}x${file.crop.h} lit=${file.litFraction.toFixed(3)} colors=${file.distinctColors} bytes=${bytes}`,
  );
  return file;
}

async function main() {
  const [apiPort, uiPort] = await freePorts(2);
  for (const port of [apiPort, uiPort]) {
    assert(!(await tcpOpen(HOST, port)), `ephemeral port ${port} taken before spawn`);
  }
  const api = start("node", ["dist-server/index.js"], {
    COCKPIT_WEB_HOST: HOST,
    COCKPIT_WEB_PORT: String(apiPort),
  });
  const preview = start(
    "node",
    [join(appRoot, "node_modules/vite/bin/vite.js"), "preview", "--host", HOST, "--strictPort", "--port", String(uiPort)],
    { COCKPIT_API_PROXY_TARGET: `http://${HOST}:${apiPort}` },
  );
  for (const [name, child] of [["api", api], ["preview", preview]]) {
    child.once("exit", (code) => { try { fail(`${name} exited early (code ${code})`, child.log()); } catch { /* exiting */ } });
  }
  try {
    await waitHttp(`http://${HOST}:${apiPort}/api/health`);
    await waitHttp(`http://${HOST}:${uiPort}/`);
  } catch (e) {
    fail(String(e), `api:\n${api.log()}\npreview:\n${preview.log()}`);
  }
  const health = await (await fetch(`http://${HOST}:${apiPort}/api/health`)).json();
  const agents = await (await fetch(`http://${HOST}:${apiPort}/api/agents`)).json();
  const viaUi = await (await fetch(`http://${HOST}:${uiPort}/api/agents`)).json();
  assert(health.status === "green" && health.source === "app/dist-server/index.js", "live API health is not green", health);
  assert(Array.isArray(agents.agents) && agents.agents.length >= 20, "fixture agents < 20", agents);
  assert(JSON.stringify(viaUi.agents) === JSON.stringify(agents.agents), "preview /api does not reach this run's API");
  const agentLabel = `Agents (${agents.agents.length})`;

  browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, locale: "en-US" });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (err) => errors.push(err.message));

  await page.goto(`http://${HOST}:${uiPort}/splash?screenshot=login`, { waitUntil: "networkidle" });
  await page.getByRole("heading", { name: "cockpit" }).waitFor();
  const healthChip = page.getByRole("button", { name: health.status, exact: true });
  await healthChip.waitFor();
  assert((await page.getByRole("button", { name: "Start GitHub device flow" }).count()) <= 1,
    "unexpected duplicate device-flow control");
  await shotAndAssert(
    page, context, join(shotDir, "t384u-login-splash.png"), "login-splash",
    page.getByRole("heading", { name: "cockpit" }),
  );

  await page.goto(`http://${HOST}:${uiPort}/workspace`, { waitUntil: "networkidle" });
  const agentsHeading = page.getByText(agentLabel, { exact: true });
  await agentsHeading.waitFor({ timeout: 20000 });
  await shotAndAssert(
    page, context, join(shotDir, "t384u-agents.png"), "agents",
    agentsHeading,
  );
  assert(errors.length === 0, "pageerror during live UI", errors);
  console.log(`t384u: ok live UI agents=${agents.agents.length} health=${health.status} shots=${shotDir}`);
  await stopChildren();
}

main().catch((err) => {
  if (!failing) fail(err && err.stack ? err.stack : String(err));
});
