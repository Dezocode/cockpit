#!/usr/bin/env python3
"""Minimal Telegram Bot API stub for notify tests (test-only)."""
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    log_path = None
    slow = False

    def log_message(self, fmt, *args):
        return

    def do_POST(self):
        if Handler.slow:
            time.sleep(2)
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        if Handler.log_path:
            with open(Handler.log_path, "a", encoding="utf-8") as f:
                f.write(f"{self.path}\n{body}\n---\n")
        if self.path.endswith("/sendMessage"):
            if "fail_token_leak" in body:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(b'{"ok":false,"description":"error bot123:SECRETTOKEN"}')
                return
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"ok":true,"result":{"message_id":1}}')
            return
        self.send_response(404)
        self.end_headers()

    def do_GET(self):
        if self.path.endswith("/getMe"):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"ok":true,"result":{"id":1,"is_bot":true}}')
            return
        self.send_response(404)
        self.end_headers()


def main():
    port = int(sys.argv[1])
    Handler.log_path = sys.argv[2] if len(sys.argv) > 2 else None
    Handler.slow = "--slow" in sys.argv
    server = HTTPServer(("127.0.0.1", port), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
