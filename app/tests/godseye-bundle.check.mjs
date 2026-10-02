#!/usr/bin/env node
import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { gzipSync } from "node:zlib";
import { execSync } from "node:child_process";

const __dirname = dirname(fileURLToPath(import.meta.url));
const appRoot = join(__dirname, "..");
const distDir = join(appRoot, "dist");
const manifestPath = join(distDir, ".vite", "manifest.json");
const baselinePath = join(__dirname, "godseye-bundle.baseline.json");

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function gzipSize(path) {
  return gzipSync(readFileSync(path)).length;
}

function walkStaticImports(manifest, entryKey, seen = new Set()) {
  if (seen.has(entryKey)) return seen;
  seen.add(entryKey);
  const chunk = manifest[entryKey];
  if (!chunk?.imports) return seen;
  for (const imp of chunk.imports) walkStaticImports(manifest, imp, seen);
  return seen;
}

function findEntryKey(manifest) {
  for (const [key, value] of Object.entries(manifest)) {
    if (value.isEntry) return key;
  }
  throw new Error("manifest entry not found");
}

function findGodsEyeChunk(manifest) {
  for (const [key, value] of Object.entries(manifest)) {
    if (key.includes("GodsEyePanel") || value.name?.includes("GodsEyePanel")) return key;
  }
  for (const [key, value] of Object.entries(manifest)) {
    if (value.isDynamicEntry && String(value.src || "").includes("GodsEyePanel")) return key;
  }
  throw new Error("GodsEyePanel chunk not found");
}

function main() {
  if (!existsSync(manifestPath)) {
    console.error("godseye-bundle: missing manifest (run pnpm build first)");
    process.exit(1);
  }
  const manifest = readJson(manifestPath);
  const entryKey = findEntryKey(manifest);
  const entryFile = join(distDir, manifest[entryKey].file);
  const entryGz = gzipSize(entryFile);
  const baseline = readJson(baselinePath);
  const maxEntry = baseline.entry_gz_bytes + 25600;
  if (entryGz > maxEntry) {
    console.error(`godseye-bundle: entry gz ${entryGz} exceeds baseline ${baseline.entry_gz_bytes}+25600`);
    process.exit(1);
  }
  const godsEyeKey = findGodsEyeChunk(manifest);
  if (!manifest[godsEyeKey].isDynamicEntry) {
    console.error("godseye-bundle: GodsEyePanel chunk must be dynamic entry");
    process.exit(1);
  }
  const staticGraph = walkStaticImports(manifest, entryKey);
  if (staticGraph.has(godsEyeKey)) {
    console.error("godseye-bundle: GodsEyePanel must not be in entry static import graph");
    process.exit(1);
  }
  const indexHtml = readFileSync(join(distDir, "index.html"), "utf8");
  if (/Cesium/i.test(indexHtml)) {
    console.error("godseye-bundle: index.html must not reference Cesium");
    process.exit(1);
  }
  const required = [
    join(distDir, "cesium/Workers"),
    join(distDir, "cesium/Assets/Textures/NaturalEarthII/tilemapresource.xml"),
    join(distDir, "cesium/LICENSE.md"),
  ];
  for (const path of required) {
    if (!existsSync(path)) {
      console.error(`godseye-bundle: missing ${path}`);
      process.exit(1);
    }
  }
  // One @cesium/engine only. cesium@1.138.0 declares @cesium/widgets ^14.3.0, but
  // widgets 14.5.0 needs engine ^24 — a second engine copy whose ContextLimits
  // are never initialised (Viewer from one engine, entities from the other):
  // "renderState.lineWidth is out of range" / "maximum texture size (0)".
  // package.json pnpm.overrides pins the matched pair; guard it here.
  const lock = readFileSync(join(appRoot, "pnpm-lock.yaml"), "utf8");
  const engines = [...new Set([...lock.matchAll(/^ {2}'@cesium\/engine@([^']+)':$/gm)].map((m) => m[1]))];
  const widgets = [...new Set([...lock.matchAll(/^ {2}'@cesium\/widgets@([^']+)':$/gm)].map((m) => m[1]))];
  if (engines.length !== 1 || widgets.length !== 1) {
    console.error(`godseye-bundle: expected exactly one @cesium/engine and @cesium/widgets, got engine=[${engines}] widgets=[${widgets}]`);
    process.exit(1);
  }
  const lazyFile = join(distDir, manifest[godsEyeKey].file);
  const lazyGz = gzipSize(lazyFile);
  console.log(
    `godseye-bundle: ok (lazy, entry+${entryGz - baseline.entry_gz_bytes}B gz vs baseline, lazy=${lazyGz}B gz, @cesium/engine@${engines[0]} single copy, index.html has no Cesium script, cesium assets copied)`,
  );
}

main();
