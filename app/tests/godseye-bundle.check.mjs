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
  const lazyFile = join(distDir, manifest[godsEyeKey].file);
  const lazyGz = gzipSize(lazyFile);
  console.log(
    `godseye-bundle: ok (lazy, entry+${entryGz - baseline.entry_gz_bytes}B gz vs baseline, lazy=${lazyGz}B gz, index.html has no Cesium script, cesium assets copied)`,
  );
}

main();
