#!/usr/bin/env node
/**
 * Playwright screenshot helper — wait for live SPA content before capture.
 * Usage: node scripts/capture-page.mjs <url> <output.png> [selector]
 */
import { chromium } from "playwright";

const [url, out, selector] = process.argv.slice(2);
if (!url || !out) {
  console.error("usage: capture-page.mjs <url> <out.png> [wait-selector]");
  process.exit(1);
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });
if (selector) {
  await page.waitForSelector(selector, { timeout: 15000 });
} else {
  await page.waitForTimeout(1500);
}
await page.screenshot({ path: out, fullPage: false });
await browser.close();
console.log(`captured ${out}`);
