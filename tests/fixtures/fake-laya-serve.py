#!/usr/bin/env python3
"""Stdlib stub of laya-serve (laya 0.3.x) for Cockpit tests only.

Wire shape mirrors laya/serve.py 0.3.20: POST /v1/systemone takes
{"state": <str|dict>, "questions": {<id>: {"type": ...}}} and answers
{"answers": {<id>: {"type","choice"|"noul","confidence","answer_confidence"}}}.
A non-object `questions` is a 400, a wrong bearer is a 401, GET /health is
unauthenticated. Configured like the real server by LAYA_HOST, LAYA_PORT and
LAYA_API_KEY; there is no default port, so every test owns an ephemeral one.

Test hooks (env): FAKE_LAYA_RECORD_DIR (writes host.txt, argv.txt, laya-env.txt, env-key.txt,
body.json, auth-ok.txt), FAKE_LAYA_SLEEP_MS / ?delay_ms= (slow answers),
FAKE_LAYA_MODE=malformed|http500, FAKE_LAYA_FORCE_TOOL, FAKE_LAYA_QUIET=1.
"""
from __future__ import annotations

import json
import os
import sys
import time
import socketserver
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

HOST = os.environ.get("LAYA_HOST", "0.0.0.0")  # same default as upstream, so a missing LAYA_HOST is visible
PORT = int(os.environ["LAYA_PORT"])
API_KEY = os.environ.get("LAYA_API_KEY") or None
RECORD_DIR = os.environ.get("FAKE_LAYA_RECORD_DIR", "")


def _record(name: str, text: str) -> None:
    if not RECORD_DIR:
        return
    with open(os.path.join(RECORD_DIR, name), "w", encoding="utf-8") as fh:
        fh.write(text)


def _request_text(state) -> str:
    if isinstance(state, dict):
        return str(state.get("request") or "")
    return str(state or "")


def _answers(text: str, questions: dict) -> dict:
    low = text.lower()
    tier, tier_conf = "standard", 0.82
    if "rename" in low or "single-file" in low:
        tier = "cheap"
    if "architecture" in low or "cross-repo" in low:
        tier = "top"
    tool_opts = list((questions.get("tool") or {}).get("criteria") or {})
    tool = "stubrt" if "stubrt" in tool_opts else (tool_opts[0] if tool_opts else "")
    tool_conf = 0.77
    if "low-confidence" in low:
        tier_conf = tool_conf = 0.4
    forced = os.environ.get("FAKE_LAYA_FORCE_TOOL", "").strip()
    if forced:
        tool = forced
    review = 0.91 if "needs-review" in low else 0.08
    sensitive = 0.93 if "sensitive" in low else 0.05
    out = {}
    if "tier" in questions:
        out["tier"] = {"type": "choice", "choice": tier, "confidence": 0.2, "answer_confidence": tier_conf}
    if "tool" in questions and tool:
        out["tool"] = {"type": "choice", "choice": tool, "confidence": 0.1, "answer_confidence": tool_conf}
    if "needs_review" in questions:
        out["needs_review"] = {"type": "noul", "noul": review, "confidence": max(review, 1 - review),
                               "answer_confidence": max(review, 1 - review)}
    if "is_sensitive" in questions:
        out["is_sensitive"] = {"type": "noul", "noul": sensitive, "confidence": max(sensitive, 1 - sensitive),
                               "answer_confidence": max(sensitive, 1 - sensitive)}
    return out


class QuickBindHTTPServer(HTTPServer):
    """HTTPServer.server_bind calls socket.getfqdn(), a reverse-DNS lookup that
    can stall for seconds on macOS runners; the stub never needs the name."""

    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        host, port = self.server_address[:2]
        self.server_name = host
        self.server_port = port


class Handler(BaseHTTPRequestHandler):
    server_version = "fake-laya-serve/2"

    def log_message(self, fmt, *args):  # noqa: D102
        if os.environ.get("FAKE_LAYA_QUIET") != "1":
            super().log_message(fmt, *args)

    def _send(self, code: int, obj) -> None:
        data = obj if isinstance(obj, bytes) else json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):  # noqa: N802
        if urlparse(self.path).path == "/health":
            self._send(200, {"status": "ok", "loaded": ["english"], "device": os.environ.get("LAYA_DEVICE") or "auto"})
            return
        self._send(404, {"detail": "Not Found"})

    def do_POST(self):  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path != "/v1/systemone":
            self._send(404, {"detail": "Not Found"})
            return
        if API_KEY is not None and self.headers.get("Authorization", "") != f"Bearer {API_KEY}":
            self._send(401, {"detail": "invalid or missing bearer token"})
            return
        _record("auth-ok.txt", "1")
        delay_ms = int(os.environ.get("FAKE_LAYA_SLEEP_MS", "0") or "0")
        qs = parse_qs(parsed.query)
        if "delay_ms" in qs:
            delay_ms = int(qs["delay_ms"][0])
        if delay_ms > 0:
            time.sleep(delay_ms / 1000.0)
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0") or "0"))
        _record("body.json", raw.decode("utf-8", "replace"))
        mode = os.environ.get("FAKE_LAYA_MODE", "")
        if mode == "malformed":
            self._send(200, b"{not json")
            return
        if mode == "http500":
            self._send(500, {"detail": "inference failed"})
            return
        try:
            body = json.loads(raw)
        except ValueError:
            self._send(400, {"detail": "request body must be valid JSON"})
            return
        if not isinstance(body, dict) or "questions" not in body:
            self._send(400, {"detail": "request body must be an object with a 'questions' field"})
            return
        if not isinstance(body["questions"], dict):
            self._send(400, {"detail": "'questions' must be an object"})
            return
        self._send(200, {"model": "fake", "answers": _answers(_request_text(body.get("state")), body["questions"]),
                         "usage": {"input_tokens": 1, "output_tokens": 0}})


def main() -> int:
    _record("host.txt", HOST)
    _record("argv.txt", "\n".join(sys.argv))
    _record("laya-env.txt", " ".join(sorted(k for k in os.environ if k.startswith("LAYA_"))))
    _record("env-key.txt", "set" if API_KEY else "unset")
    httpd = QuickBindHTTPServer((HOST, PORT), Handler)
    _record("listening.txt", "%s:%d" % httpd.server_address[:2])
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
