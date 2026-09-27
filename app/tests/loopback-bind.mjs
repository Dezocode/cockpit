// Test-only preload (node --import): force host-less listen() calls onto
// 127.0.0.1 so the e2e API never binds beyond loopback. The product bind is
// owned by C3 (COCKPIT_WEB_HOST); this file never ships in dist-server.
import net from "node:net";

const listen = net.Server.prototype.listen;
net.Server.prototype.listen = function loopbackListen(...args) {
  if (typeof args[0] === "number" || (typeof args[0] === "string" && /^\d+$/.test(args[0]))) {
    if (typeof args[1] !== "string") args.splice(1, 0, "127.0.0.1");
  } else if (args[0] && typeof args[0] === "object" && args[0].port !== undefined && !args[0].host) {
    args[0] = { ...args[0], host: "127.0.0.1" };
  }
  return listen.apply(this, args);
};
