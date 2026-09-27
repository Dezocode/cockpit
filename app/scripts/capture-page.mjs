#!/usr/bin/env node
/**
 * Playwright screenshot helper — wait for live SPA content before capture.
 * Usage: node scripts/capture-page.mjs <url> <output.png> [selector | wait-ms]
 */
import { chromium } from "playwright";

const [url, out, wait] = process.argv.slice(2);
if (!url || !out) {
  console.error("usage: capture-page.mjs <url> <out.png> [selector | wait-ms]");
  process.exit(1);
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });
if (wait && /^\d+$/.test(wait)) {
  await page.waitForTimeout(Number(wait));
} else if (wait) {
  await page.waitForSelector(wait, { timeout: 15000 });
} else {
  await page.waitForTimeout(1500);
}
await page.screenshot({ path: out, fullPage: false });
await browser.close();
console.log(`captured ${out}`);
