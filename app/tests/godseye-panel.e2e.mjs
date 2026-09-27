#!/usr/bin/env node
// C10 GOD'S EYE e2e: real built API (dist-server) + built UI (vite preview), both
// on 127.0.0.1, Chromium headless on SwiftShader. Egress to any non-loopback host
// is aborted AND counted (must be 0). Asserts the Cesium canvas has a real
// layout box and actually rendered the globe (pixel check), node/unplaced counts
// match /api/computers, credits are shown, arcs render and a theme switch
// recolors nodes (explicit-geo test roster, so it never depends on TZ), and
// close/reopen 3x leaves <=1 live viewer.
// Ports: the API and vite preview each get an ephemeral 127.0.0.1 port this
// test owns (bind :0); preview proxies /api to it via COCKPIT_API_PROXY_TARGET.
// Teardown stops only the processes this test spawned (child handles), never
// anything found by port.
// Env: GODSEYE_SHOT / GODSEYE_ARCS_SHOT = screenshot paths (each PNG is
// re-checked for a rendered globe); GODSEYE_EXPECT_NODES / GODSEYE_EXPECT_UNPLACED
// = exact placed/unplaced counts to assert (CI pins them per TZ).
import { spawn } from "node:child_process";
import { createServer, connect } from "node:net";
import { networkInterfaces } from "node:os";
import { chromium } from "playwright";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const appRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const HOST = "127.0.0.1";
// The e2e machine "lives" in this IANA zone so the local node is placed by the
// server's tz ladder (zone1970.tab). CI runners default to UTC, which is
// correctly unplaced (no invented coordinates).
const E2E_TZ = process.env.GODSEYE_E2E_TZ || "America/Chicago";
const KEY_ENV = ["CESIUM_ION_TOKEN", "GOOGLE_MAPS_API_KEY", "VITE_CESIUM_ION_TOKEN", "VITE_GOOGLE_MAPS_API_KEY"];
// Stripped so placement is decided by E2E_TZ alone (and a stray proxy target
// can never point preview at someone else's server).
const PLACEMENT_ENV = ["COCKPIT_NODE_GEO", "COCKPIT_API_PROXY_TARGET"];

const children = []; // only processes this test spawned; teardown uses these handles
const consoleErrors = [];
const glWarnings = [];
let browser = null;

/**
 * Signal a child we spawned. Every child is spawned `detached: true`, i.e. it leads
 * its own process group (pgid === pid) that this test created, so the whole group
 * (vite -> esbuild, node workers) is signalled via process.kill(-pid). A group is
 * only signalled while its leader is still our live child, never after it exited
 * (the pgid could then belong to someone else), and never anything found by port.
 */
function signalChild(c, sig) {
  if (c.ownGroup && c.exitCode === null && c.signalCode === null) {
    try {
      process.kill(-c.pid, sig);
      return;
    } catch {
      /* group already gone: fall back to the handle */
    }
  }
  try {
    c.kill(sig);
  } catch {
    /* already exited */
  }
}

/** Stop exactly the children (and their own process groups) we spawned: SIGTERM, then SIGKILL after 5 s. */
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

class E2EFail extends Error {}
let failing = false;
function fail(message, extra) {
  if (!failing) {
    failing = true;
    console.error(`godseye: FAIL ${message}`);
    if (extra !== undefined) console.error(typeof extra === "string" ? extra : JSON.stringify(extra, null, 2));
    if (consoleErrors.length) console.error("console errors so far:", consoleErrors.slice(0, 10));
    if (glWarnings.length) console.error("WebGL warnings so far:", glWarnings.slice(0, 10));
    stopChildren().finally(() => process.exit(1));
  }
  throw new E2EFail(message);
}
for (const sig of ["SIGINT", "SIGTERM"]) {
  process.once(sig, () => { try { fail(`interrupted (${sig})`); } catch { /* exiting */ } });
}
function assert(cond, message, extra) {
  if (!cond) fail(message, extra);
}

/** n distinct ephemeral ports on 127.0.0.1: all held open together (so they differ), then released for our children. */
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

function start(cmd, args, env) {
  const baseEnv = { ...process.env };
  for (const k of [...KEY_ENV, ...PLACEMENT_ENV]) delete baseEnv[k];
  const child = spawn(cmd === "node" ? process.execPath : cmd, args, {
    cwd: appRoot,
    env: { ...baseEnv, ...env },
    stdio: ["ignore", "pipe", "pipe"],
    detached: true, // own process group, so teardown can stop grandchildren too
  });
  child.ownGroup = process.platform !== "win32" && typeof child.pid === "number";
  let log = "";
  child.stdout.on("data", (d) => (log += d));
  child.stderr.on("data", (d) => (log += d));
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
    } catch {
      /* not up yet */
    }
    await sleep(250);
  }
  throw new Error(`timeout waiting for ${url}`);
}

/** Resolve true if something accepts TCP on ip:port. */
function tcpOpen(ip, port) {
  return new Promise((resolve) => {
    const sock = connect({ host: ip, port, timeout: 1500 });
    sock.once("connect", () => { sock.destroy(); resolve(true); });
    sock.once("error", () => resolve(false));
    sock.once("timeout", () => { sock.destroy(); resolve(false); });
  });
}

/** In-page: canvas box + pixel statistics of the Cesium drawing buffer. */
async function canvasStats(page, targets = {}) {
  return page.evaluate((targets) => {
    const host = document.querySelector("[data-testid=godseye-canvas]");
    const canvas = host?.querySelector("canvas");
    if (!host || !canvas) return { present: false };
    const hostBox = host.getBoundingClientRect();
    const out = {
      present: true,
      host: { w: Math.round(hostBox.width), h: Math.round(hostBox.height) },
      css: { w: canvas.clientWidth, h: canvas.clientHeight },
      buffer: { w: canvas.width, h: canvas.height },
      dpr: window.devicePixelRatio,
    };
    if (!canvas.width || !canvas.height) return out;
    const off = document.createElement("canvas");
    off.width = canvas.width;
    off.height = canvas.height;
    const ctx = off.getContext("2d", { willReadFrequently: true });
    ctx.drawImage(canvas, 0, 0);
    const { data } = ctx.getImageData(0, 0, off.width, off.height);
    const colors = new Set();
    let lit = 0;
    const near = Object.fromEntries(Object.keys(targets).map((k) => [k, 0]));
    const px = data.length / 4;
    for (let i = 0; i < data.length; i += 4) {
      const r = data[i], g = data[i + 1], b = data[i + 2];
      if (Math.max(r, g, b) > 48) lit += 1;
      colors.add(((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3));
      for (const [k, [tr, tg, tb, tol = 24]] of Object.entries(targets)) {
        const d = (r - tr) ** 2 + (g - tg) ** 2 + (b - tb) ** 2;
        if (d < tol * tol) near[k] += 1;
      }
    }
    out.litFraction = lit / px;
    out.distinctColors = colors.size;
    out.near = near;
    return out;
  }, targets);
}

// Rendered-globe thresholds (canvas and re-read PNG crop alike). Observed on the
// SwiftShader CI leg: a rendered globe gives 771-1362 distinct 15-bit colors
// (CI 36325107973 @c44119d: 784-1361, lit 0.194-0.255); the hidden-tab /
// not-yet-rendered canvas gives 159 colors. 300 sits well clear of both, so a blank
// or half-initialised frame fails on colors too, not on lit alone.
const GLOBE_MIN_LIT = 0.08;
const GLOBE_MIN_COLORS = 300;

function globeRendered(s) {
  return s.present && s.litFraction >= GLOBE_MIN_LIT && s.distinctColors >= GLOBE_MIN_COLORS;
}

async function waitGlobe(page, label, timeoutMs = 60000) {
  const t0 = Date.now();
  let s;
  while (Date.now() - t0 < timeoutMs) {
    s = await canvasStats(page);
    if (globeRendered(s)) return s;
    await sleep(1000);
  }
  fail(`${label}: globe never rendered into the canvas`, s);
}

function assertCanvasBox(s, label) {
  assert(s.present, `${label}: no <canvas> inside [data-testid=godseye-canvas]`);
  assert(s.host.w > 100 && s.host.h > 100, `${label}: canvas host has no layout box`, s);
  assert(s.css.w > 100 && s.css.h > 100, `${label}: canvas has no layout box`, s);
  assert(Math.abs(s.css.w - s.host.w) <= 2 && Math.abs(s.css.h - s.host.h) <= 2,
    `${label}: canvas does not fill its host (intrinsic-size canvas)`, s);
  assert(s.buffer.w >= s.css.w * 0.95 && s.buffer.h >= s.css.h * 0.95,
    `${label}: drawing buffer not sized to the canvas`, s);
}

/** No error / fallback / placeholder text: none on the page, none inside the GOD'S EYE panel. */
async function assertNoFallbackText(page, label) {
  const text = await page.evaluate(() => ({
    body: document.body.innerText,
    root: document.querySelector("[data-testid=godseye-root]")?.innerText ?? null,
  }));
  assert(text.root !== null, `${label}: [data-testid=godseye-root] missing (fallback rendered instead of the globe)`);
  const bad = /Globe unavailable|initialising globe/i.exec(text.body) ?? /unavailable|error|failed/i.exec(text.root);
  assert(!bad, `${label}: error/fallback/placeholder text on screen: "${bad?.[0]}"`, text.root.slice(0, 800));
}

/**
 * Screenshot, then re-read the PNG file itself: crop the canvas box out of the
 * saved image and require the same globe thresholds, so the artifact can never
 * be a blank/error frame even if the live canvas check passed a moment earlier.
 */
async function shotAndCheck(page, path, label) {
  const live = await canvasStats(page);
  assert(globeRendered(live), `${label}: globe not rendered at screenshot time`, live);
  assertCanvasBox(live, label);
  await assertNoFallbackText(page, label);
  const box = await page.locator("[data-testid=godseye-canvas]").boundingBox();
  const png = await page.screenshot({ path });
  const probe = await page.context().newPage();
  const file = await probe.evaluate(async ({ b64, box }) => {
    const img = new Image();
    img.src = `data:image/png;base64,${b64}`;
    await img.decode();
    const c = document.createElement("canvas");
    c.width = Math.round(box.width);
    c.height = Math.round(box.height);
    const ctx = c.getContext("2d", { willReadFrequently: true });
    ctx.drawImage(img, Math.round(box.x), Math.round(box.y), c.width, c.height, 0, 0, c.width, c.height);
    const { data } = ctx.getImageData(0, 0, c.width, c.height);
    const colors = new Set();
    let lit = 0;
    for (let i = 0; i < data.length; i += 4) {
      const r = data[i], g = data[i + 1], b = data[i + 2];
      if (Math.max(r, g, b) > 48) lit += 1;
      colors.add(((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3));
    }
    return { image: { w: img.naturalWidth, h: img.naturalHeight }, crop: { w: c.width, h: c.height }, litFraction: lit / (data.length / 4), distinctColors: colors.size };
  }, { b64: png.toString("base64"), box });
  await probe.close();
  assert(file.crop.w > 100 && file.crop.h > 100, `${label}: screenshot canvas crop has no box`, file);
  assert(file.litFraction >= GLOBE_MIN_LIT && file.distinctColors >= GLOBE_MIN_COLORS,
    `${label}: screenshot PNG shows no rendered globe`, file);
  console.log(
    `godseye: screenshot ${path} (${label}: png=${file.image.w}x${file.image.h}, canvas=${file.crop.w}x${file.crop.h}, ` +
      `lit=${file.litFraction.toFixed(3)}, colors=${file.distinctColors})`,
  );
  return file;
}

async function addPanel(page) {
  await page.getByText("GODSEYE", { exact: true }).dblclick({ timeout: 60000 });
  await page.waitForSelector("[data-testid=godseye-canvas]", { timeout: 60000 });
  await page.waitForFunction(() => window.__cockpitGodsEye?.ready === true, null, { timeout: 90000 });
}

async function closePanels(page) {
  await page.evaluate(() => {
    const api = window.__cockpitDockviewApi;
    if (!api) return;
    for (const panel of [...api.panels]) {
      if ((panel.params || {}).panelType === "GODSEYE") panel.api.close();
    }
  });
  await page.waitForSelector("[data-testid=godseye-canvas]", { state: "detached", timeout: 30000 });
}

function hexToRgb(hex) {
  const h = hex.trim().replace(/^#/, "");
  const full = h.length === 3 ? h.split("").map((c) => c + c).join("") : h;
  return [0, 2, 4].map((i) => parseInt(full.slice(i, i + 2), 16));
}

async function main() {
  // Both ports are ephemeral and owned by this run: the API listens on
  // HOST:apiPort via the product COCKPIT_WEB_HOST bind (loopback by default) and
  // vite preview proxies /api + /ws to it through COCKPIT_API_PROXY_TARGET.
  const [apiPort, uiPort] = await freePorts(2);
  for (const port of [apiPort, uiPort]) {
    assert(!(await tcpOpen(HOST, port)), `ephemeral port ${port} taken before spawn; refusing to test against a foreign server`);
  }
  const api = start("node", ["dist-server/index.js"], {
    COCKPIT_WEB_HOST: HOST,
    COCKPIT_WEB_PORT: String(apiPort),
    TZ: E2E_TZ,
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
    await waitHttp(`http://${HOST}:${apiPort}/api/computers`);
    await waitHttp(`http://${HOST}:${uiPort}/`);
  } catch (e) {
    fail(String(e), `api:\n${api.log()}\npreview:\n${preview.log()}`);
  }
  // Loopback only: the API and UI must refuse connections on every non-loopback address.
  const external = Object.values(networkInterfaces()).flat().filter((i) => i && !i.internal && i.family === "IPv4");
  for (const iface of external) {
    for (const port of [apiPort, uiPort]) {
      assert(!(await tcpOpen(iface.address, port)), `port ${port} reachable on non-loopback ${iface.address}`);
    }
  }
  // Roster straight from the built API (the panel must agree with it), and the
  // same roster through the preview proxy: proves preview targets OUR API port.
  const direct = await (await fetch(`http://${HOST}:${apiPort}/api/computers`)).json();
  const roster = await (await fetch(`http://${HOST}:${uiPort}/api/computers`)).json();
  assert(JSON.stringify(roster) === JSON.stringify(direct), "preview /api proxy does not reach this run's API", { direct, roster });
  const expectPlaced = roster.computers.filter((c) => c.geo).map((c) => c.name);
  const expectUnplaced = roster.computers.filter((c) => !c.geo).map((c) => c.name);
  for (const [envName, got] of [["GODSEYE_EXPECT_NODES", expectPlaced.length], ["GODSEYE_EXPECT_UNPLACED", expectUnplaced.length]]) {
    const want = process.env[envName];
    if (want !== undefined && want !== "") assert(got === Number(want), `${envName}=${want} but roster gives ${got} (TZ=${E2E_TZ})`, roster);
  }

  browser = await chromium.launch({
    headless: true,
    args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
  });
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, locale: "en-US" });
  const page = await context.newPage();
  page.on("console", (msg) => {
    const text = msg.text();
    if (msg.type() === "error") consoleErrors.push(text);
    if (/too many active webgl contexts|context lost|CONTEXT_LOST|Rendering has stopped/i.test(text)) glWarnings.push(text);
  });
  page.on("pageerror", (err) => consoleErrors.push(`pageerror: ${err.message}`));
  let nonLoopbackAttempts = 0;
  const blocked = [];
  let rosterOverride = null;
  await page.route("**/*", (route) => {
    const url = new URL(route.request().url());
    if (url.hostname !== HOST && url.hostname !== "localhost") {
      nonLoopbackAttempts += 1;
      blocked.push(url.hostname);
      return route.abort();
    }
    if (rosterOverride && url.pathname === "/api/computers") {
      return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(rosterOverride) });
    }
    return route.continue();
  });

  await page.goto(`http://${HOST}:${uiPort}/splash/staging?reset=1`, { waitUntil: "networkidle" });
  await page.evaluate(() => localStorage.setItem("cockpit.theme", "fieldset-dark"));
  await page.goto(`http://${HOST}:${uiPort}/splash/staging?reset=1`, { waitUntil: "networkidle" });

  // 1) open from palette; the canvas must have a real box and render the globe.
  await addPanel(page);
  const first = await waitGlobe(page, "open");
  assertCanvasBox(first, "open");
  const diag = await page.evaluate(() => window.__cockpitGodsEye);
  assert(Object.keys(diag).sort().join(",") === "entityCount,liveViewers,ready,unplaced",
    "window.__cockpitGodsEye must expose only {ready, entityCount, liveViewers, unplaced}", diag);
  assert(diag.entityCount === expectPlaced.length, `entityCount ${diag.entityCount} != placed ${expectPlaced.length}`, roster);
  assert(diag.unplaced === expectUnplaced.length, `unplaced ${diag.unplaced} != ${expectUnplaced.length}`, roster);
  const placedNames = await page.locator("[data-testid=godseye-placed] li").allInnerTexts();
  const unplacedNames = await page.locator("[data-testid=godseye-unplaced] li").allInnerTexts();
  assert(JSON.stringify(placedNames) === JSON.stringify(expectPlaced), "placed list mismatch", { placedNames, expectPlaced });
  assert(JSON.stringify(unplacedNames) === JSON.stringify(expectUnplaced), "unplaced list mismatch", { unplacedNames, expectUnplaced });
  await page.waitForFunction(
    () => /Natural Earth/.test(document.querySelector("[data-testid=godseye-credits]")?.textContent ?? ""),
    null, { timeout: 30000 },
  ).catch(() => fail("credits line does not show Natural Earth"));
  await sleep(4000); // let imagery settle for the screenshot
  await assertNoFallbackText(page, "open");
  if (process.env.GODSEYE_SHOT) await shotAndCheck(page, process.env.GODSEYE_SHOT, "keyless");

  // 3) close + reopen 3x: one live viewer at most, and each reopen renders.
  for (let i = 0; i < 3; i += 1) {
    await closePanels(page);
    await addPanel(page);
    assertCanvasBox(await waitGlobe(page, `reopen ${i + 1}`), `reopen ${i + 1}`);
  }
  const afterReopen = await page.evaluate(() => window.__cockpitGodsEye);
  assert(afterReopen.liveViewers <= 1, `liveViewers=${afterReopen.liveViewers} after 3x close/reopen`);

  // 3b) mount-before-layout: a GOD'S EYE tab added inactive behind COMPUTERS has
  //     a 0x0 (detached/hidden) container. The panel must wait (ResizeObserver),
  //     not error, and create the viewer only once the tab is shown.
  await closePanels(page);
  await page.evaluate(() => {
    const api = window.__cockpitDockviewApi;
    api.addPanel({ id: "e2e-computers", component: "staging", title: "COMPUTERS", params: { panelType: "COMPUTERS" } });
    api.addPanel({
      id: "e2e-godseye-hidden",
      component: "staging",
      title: "GOD'S EYE",
      params: { panelType: "GODSEYE" },
      position: { referencePanel: "e2e-computers", direction: "within" },
      inactive: true,
    });
  });
  await sleep(3000);
  const hidden = await page.evaluate(() => ({
    diag: window.__cockpitGodsEye ?? null,
    error: /Globe unavailable/.test(document.body.innerText),
  }));
  assert(!hidden.error, "hidden tab: panel errored instead of waiting for layout", hidden);
  assert(!hidden.diag?.ready && (hidden.diag?.liveViewers ?? 0) === 0,
    "hidden tab: viewer created before the container had a layout box", hidden);
  await page.evaluate(() => window.__cockpitDockviewApi.getPanel("e2e-godseye-hidden").api.setActive());
  await page.waitForFunction(() => window.__cockpitGodsEye?.ready === true, null, { timeout: 90000 })
    .catch(() => fail("hidden tab: viewer never initialised after the tab became visible"));
  assertCanvasBox(await waitGlobe(page, "hidden tab shown"), "hidden tab shown");
  await page.evaluate(() => window.__cockpitDockviewApi.getPanel("e2e-computers")?.api.close());

  // 4) arcs: a test-only roster (explicit geo on every row) must draw local→node
  //    polylines + latency labels under headless WebGL. Product fixture rows are
  //    never given coordinates; this payload only exists inside this test.
  rosterOverride = {
    computers: [
      { id: "local", name: "e2e-local", status: "online", latencyMs: 0, geo: { lat: 41.85, lon: -87.65 }, geoSource: "explicit" },
      { id: "e2e-a", name: "e2e-a", status: "online", latencyMs: 12, geo: { lat: 51.5, lon: -0.12 }, geoSource: "explicit" },
      { id: "e2e-b", name: "e2e-b", status: "online", latencyMs: 42, geo: { lat: -23.55, lon: -46.63 }, geoSource: "explicit" },
    ],
    offlineThresholdMs: 3000,
  };
  await closePanels(page);
  await addPanel(page);
  await waitGlobe(page, "arcs");
  const counts = await page.locator("[data-testid=godseye-counts]").innerText();
  assert(/3\s+placed/.test(counts) && /2\s+arcs/.test(counts), "arcs roster: expected 3 placed / 2 arcs", counts);
  await sleep(2000);
  const darkAccent = hexToRgb(await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--cockpit-accent")));
  const arcPixels = (await canvasStats(page, { accent: [...darkAccent, 64] })).near.accent;
  // 3 points ≈ 3×80 px; two ~7000 km geodesic arcs add several hundred more.
  assert(arcPixels >= 450, "arc polylines not visible in the canvas", { arcPixels });
  if (process.env.GODSEYE_ARCS_SHOT) await shotAndCheck(page, process.env.GODSEYE_ARCS_SHOT, "arcs");

  // 2) theme switch recolors placed nodes (tokens → Cesium colors at runtime).
  //    Runs on the explicit-geo roster (always 3 placed), never gated on the
  //    product roster's placed count, so it holds under every TZ (incl. UTC).
  const tokens = async () => page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--cockpit-accent"));
  const beforeDark = (await canvasStats(page, { dark: darkAccent })).near.dark;
  await page.locator('button[data-theme="ghui-cyan"]').click();
  await page.waitForFunction(() => document.documentElement.dataset.theme === "ghui-cyan");
  const cyanAccent = hexToRgb(await tokens());
  await sleep(1500);
  const after = await canvasStats(page, { dark: darkAccent, cyan: cyanAccent });
  assert(beforeDark >= 20, "no node pixels in the fieldset-dark accent before theme switch", { beforeDark, darkAccent });
  assert(after.near.cyan >= 20 && after.near.dark < beforeDark / 2,
    "theme switch did not recolor nodes", { beforeDark, after: after.near, darkAccent, cyanAccent });
  await page.locator('button[data-theme="fieldset-dark"]').click();
  await page.waitForFunction(() => document.documentElement.dataset.theme === "fieldset-dark");
  rosterOverride = null;
  await closePanels(page);

  assert(consoleErrors.length === 0, "console errors", consoleErrors);
  assert(glWarnings.length === 0, "WebGL context loss / render stop warnings", glWarnings);
  assert(nonLoopbackAttempts === 0, `non-loopback request attempts=${nonLoopbackAttempts}`, blocked);

  await stopChildren();
  browser = null;
  console.log(
    `godseye: ok (keyless, offline, tz=${E2E_TZ}, nodes=${expectPlaced.length}, unplaced=${expectUnplaced.length}, ` +
      `canvas=${first.css.w}x${first.css.h}, lit=${first.litFraction.toFixed(3)}, colors=${first.distinctColors}, ` +
      `arcs=2 px=${arcPixels}, recolor=${beforeDark}->${after.near.cyan}, non-loopback=0, ` +
      `liveViewers=${afterReopen.liveViewers}, ports=api:${apiPort},ui:${uiPort})`,
  );
}

main().catch((error) => {
  if (error instanceof E2EFail) return; // fail() already reported and is tearing down
  try { fail(error?.stack ?? String(error)); } catch { /* exiting */ }
});
