#!/usr/bin/env python3
"""Test-only stub standing in for api.telegram.org (COCKPIT_TELEGRAM_API_BASE) and an
ntfy server (COCKPIT_NTFY_SERVER). Never used by product code.

usage: fake-telegram-api.py PORTFILE LOGFILE [--slow SECONDS]
Binds 127.0.0.1:0 (ephemeral), writes the chosen port to PORTFILE, appends one JSON
line per request (method, path, headers, body) to LOGFILE.
"""
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    log_path = None
    slow = 0.0

    def log_message(self, fmt, *args):
        return

    def _record(self, body):
        with open(Handler.log_path, "a", encoding="utf-8") as f:
            f.write(json.dumps({"method": self.command, "path": self.path,
                                "headers": dict(self.headers.items()), "body": body}) + "\n")

    def _reply(self, code, payload):
        data = payload.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        if Handler.slow:
            time.sleep(Handler.slow)
        self._record(body)
        if "/bot" in self.path and self.path.endswith("/sendMessage"):
            if "fail_token_leak" in body:
                # Echo the request path (it carries bot<TOKEN>) to prove the CLI redacts it.
                self._reply(500, json.dumps({"ok": False, "description": "boom at " + self.path}))
                return
            self._reply(200, '{"ok":true,"result":{"message_id":1}}')
            return
        if "fail_ntfy" in body:
            self._reply(500, json.dumps({"error": "ntfy down for " + self.path}))
            return
        # ntfy publish: any other POST path is the topic.
        self._reply(200, json.dumps({"id": "stub", "event": "message", "message": body}))

    def do_GET(self):
        self._record("")
        if "/bot" in self.path and self.path.endswith("/getMe"):
            self._reply(200, '{"ok":true,"result":{"id":1,"is_bot":true}}')
            return
        self._reply(404, '{"ok":false}')


def main():
    portfile, Handler.log_path = sys.argv[1], sys.argv[2]
    if "--slow" in sys.argv:
        Handler.slow = float(sys.argv[sys.argv.index("--slow") + 1])
    server = HTTPServer(("127.0.0.1", 0), Handler)
    with open(portfile + ".tmp", "w") as f:
        f.write(str(server.server_address[1]))
    import os
    os.replace(portfile + ".tmp", portfile)
    server.serve_forever()


if __name__ == "__main__":
    main()
