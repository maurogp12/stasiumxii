#!/usr/bin/env python3
"""Static HTTP server for the launcher tests and the update proof.

Adds what python's http.server lacks:
  - Range requests (bytes=N- and bytes=N-M) answered with 206;
  - ?cut=N   send the full Content-Length but drop the connection after N body bytes;
  - ?norange=1  ignore Range and answer 200 (a server that cannot resume);
  - --rate B   throttle every response to B bytes per second (for the clip);
  - --log F    one JSON line per request: path, range, status, bytes sent.

Usage: launcher_fixture_server.py --root DIR [--port 0] [--port-file F] [--log F] [--rate B]
"""

import argparse
import json
import os
import posixpath
import socket
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ARGS = None
LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *a):
        pass

    def handle(self):
        try:
            super().handle()
        except (ConnectionResetError, BrokenPipeError):
            pass

    def _log(self, path, rng, status, sent):
        if not ARGS.log:
            return
        with LOCK, open(ARGS.log, "a") as f:
            f.write(json.dumps({"path": path, "range": rng, "status": status, "sent": sent}) + "\n")

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        q = urllib.parse.parse_qs(parsed.query)
        rel = posixpath.normpath(urllib.parse.unquote(parsed.path)).lstrip("/")
        full = os.path.join(ARGS.root, rel)
        if rel.startswith("..") or not os.path.isfile(full):
            body = b"not found"
            self.send_response(404)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            self._log(parsed.path, None, 404, 0)
            return
        size = os.path.getsize(full)
        start, end = 0, size - 1
        rng = self.headers.get("Range")
        status = 200
        if rng and "norange" not in q:
            spec = rng.replace("bytes=", "").split("-")
            start = int(spec[0]) if spec[0] else 0
            end = int(spec[1]) if len(spec) > 1 and spec[1] else size - 1
            if start >= size:
                self.send_response(416)
                self.send_header("Content-Range", f"bytes */{size}")
                self.send_header("Content-Length", "0")
                self.end_headers()
                self._log(parsed.path, rng, 416, 0)
                return
            status = 206
        length = end - start + 1
        self.send_response(status)
        self.send_header("Content-Length", str(length))
        self.send_header("Accept-Ranges", "bytes")
        if status == 206:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()
        cut = int(q["cut"][0]) if "cut" in q else -1
        sent = 0
        t0 = time.monotonic()
        try:
            with open(full, "rb") as f:
                f.seek(start)
                while sent < length:
                    n = min(64 * 1024, length - sent)
                    if cut >= 0:
                        n = min(n, cut - sent)
                        if n <= 0:
                            self.connection.shutdown(socket.SHUT_RDWR)
                            self.close_connection = True
                            break
                    b = f.read(n)
                    self.wfile.write(b)
                    sent += len(b)
                    if ARGS.rate:
                        ahead = sent / ARGS.rate - (time.monotonic() - t0)
                        if ahead > 0:
                            time.sleep(ahead)
        except (BrokenPipeError, ConnectionResetError):
            pass
        self._log(parsed.path, rng, status, sent)


def main():
    global ARGS
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--port-file")
    ap.add_argument("--log")
    ap.add_argument("--rate", type=float, default=0.0)
    ARGS = ap.parse_args()
    srv = ThreadingHTTPServer(("127.0.0.1", ARGS.port), Handler)
    srv.daemon_threads = True
    if ARGS.port_file:
        with open(ARGS.port_file + ".tmp", "w") as f:
            f.write(str(srv.server_address[1]))
        os.replace(ARGS.port_file + ".tmp", ARGS.port_file)
    print("serving", ARGS.root, "on", srv.server_address[1], flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
