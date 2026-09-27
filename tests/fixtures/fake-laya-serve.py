#!/usr/bin/env python3
"""Stdlib stub of Laya POST /v1/systemone for Cockpit tests only."""
from __future__ import annotations

import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

HOST = os.environ.get("LAYA_HOST", "127.0.0.1")
PORT = int(os.environ.get("LAYA_PORT", "8765"))
API_KEY = os.environ.get("LAYA_API_KEY", "test-key")
RECORD_HOST = os.environ.get("LAYA_RECORD_HOST_FILE", "")


def _answers_for_task(task: str) -> dict:
    task_l = task.lower()
    tier = "standard"
    tool = "stubrt"
    tier_conf = 0.82
    tool_conf = 0.77
    if "rename" in task_l or "single-file" in task_l:
        tier = "cheap"
    if "architecture" in task_l or "cross-repo" in task_l:
        tier = "top"
    if "low-confidence" in task_l or "low confidence" in task_l:
        tier_conf = 0.4
        tool_conf = 0.4
    if "tool-codex" in task_l:
        tool = "codex"
    forced = os.environ.get("LAYA_FORCE_TOOL", "").strip()
    if forced:
        tool = forced
    needs_review = "needs-review" in task_l
    is_sensitive = "sensitive" in task_l and "non-sensitive" not in task_l
    return {
        "tier": {"choice": tier, "confidence": tier_conf},
        "tool": {"choice": tool, "confidence": tool_conf},
        "needs_review": {"noul": needs_review, "confidence": 0.9 if needs_review else 0.1},
        "is_sensitive": {"noul": is_sensitive, "confidence": 0.9 if is_sensitive else 0.1},
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "fake-laya-serve/1"

    def log_message(self, fmt, *args):  # noqa: D102
        if os.environ.get("LAYA_STUB_QUIET") == "1":
            return
        super().log_message(fmt, *args)

    def do_POST(self):  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path != "/v1/systemone":
            self.send_error(404)
            return
        auth = self.headers.get("Authorization", "")
        if auth != f"Bearer {API_KEY}":
            self.send_error(401)
            return
        delay_ms = 0
        qs = parse_qs(parsed.query)
        if "delay_ms" in qs:
            try:
                delay_ms = int(qs["delay_ms"][0])
            except (TypeError, ValueError):
                delay_ms = 0
        env_delay = int(os.environ.get("LAYA_STUB_SLEEP_MS", "0") or "0")
        if env_delay > 0:
            time.sleep(env_delay / 1000.0)
        if delay_ms > 0:
            time.sleep(delay_ms / 1000.0)
        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(body.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            payload = {}
        task = ""
        if isinstance(payload.get("context"), dict):
            task = str(payload["context"].get("task") or "")
        if not task:
            task = str(payload.get("task") or "")
        answers = _answers_for_task(task)
        out = {"answers": answers}
        data = json.dumps(out).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):  # noqa: N802
        if self.path.startswith("/v1/systemone"):
            self.send_response(200)
            self.end_headers()
            return
        self.send_error(404)


def main() -> int:
    if RECORD_HOST:
        try:
            with open(RECORD_HOST, "w", encoding="utf-8") as fh:
                fh.write(HOST)
        except OSError:
            pass
    httpd = HTTPServer((HOST, PORT), Handler)
    httpd.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
