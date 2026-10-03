import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { viteStaticCopy } from "vite-plugin-static-copy";
import process from "node:process";

const host = process.env.TAURI_DEV_HOST;
// Where dev/preview proxy /api and /ws. Default is the local API on 8787;
// tests set COCKPIT_API_PROXY_TARGET (http://127.0.0.1:<ephemeral>) so they
// never depend on, or collide with, a server already holding the dev port.
const apiTarget = (process.env.COCKPIT_API_PROXY_TARGET || "http://localhost:8787").replace(/\/+$/, "");
const wsTarget = apiTarget.replace(/^http/, "ws");
const apiProxy = () => ({
  "/api": { target: apiTarget, changeOrigin: true },
  "/ws": { target: wsTarget, ws: true },
});

export default defineConfig(() => ({
  plugins: [
    react(),
    tailwindcss(),
    viteStaticCopy({
      targets: [
        { src: "node_modules/cesium/Build/Cesium/Workers", dest: "cesium" },
        { src: "node_modules/cesium/Build/Cesium/Assets", dest: "cesium" },
        { src: "node_modules/cesium/Build/Cesium/ThirdParty", dest: "cesium" },
        { src: "node_modules/cesium/Build/Cesium/Widgets", dest: "cesium" },
        { src: "node_modules/cesium/LICENSE.md", dest: "cesium" },
      ],
    }),
  ],
  define: {
    CESIUM_BASE_URL: JSON.stringify("/cesium"),
  },
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
    host: host || false,
    hmr: host ? { protocol: "ws", host, port: 1421 } : undefined,
    watch: { ignored: ["**/src-tauri/**"] },
    proxy: apiProxy(),
    fs: {
      deny: [".env", ".env.*", "*.crt", "*.pem", "**/.git/**", "**/ENVIRONMENT", "**/keys.env"],
    },
  },
  preview: {
    port: 1420,
    strictPort: true,
    proxy: apiProxy(),
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    manifest: true,
  },
}));
