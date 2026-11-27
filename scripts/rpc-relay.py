#!/usr/bin/env python3
"""Local HTTP relay to a remote Gno RPC.

gnokey's RPC client dials TCP itself and ignores HTTPS_PROXY. In sandboxes
where outbound traffic must go through a proxy, run this relay and point
gnokey at it instead:

    scripts/rpc-relay.py https://rpc.onyx.testnets.gno.land 127.0.0.1:26690 &
    gnokey query bank/balances/g1... -remote http://127.0.0.1:26690

Python's urllib honours HTTPS_PROXY, so the relay works through the proxy.
Not needed on a normal machine: use -remote https://rpc.onyx.testnets.gno.land:443.
"""
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPSTREAM = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "https://rpc.onyx.testnets.gno.land"
LISTEN = sys.argv[2] if len(sys.argv) > 2 else "127.0.0.1:26690"


class Relay(BaseHTTPRequestHandler):
    def _forward(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        req = urllib.request.Request(UPSTREAM + self.path, data=body, method=self.command)
        if self.headers.get("Content-Type"):
            req.add_header("Content-Type", self.headers["Content-Type"])
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                status, data, ctype = resp.status, resp.read(), resp.headers.get("Content-Type")
        except urllib.error.HTTPError as e:
            status, data, ctype = e.code, e.read(), e.headers.get("Content-Type")
        self.send_response(status)
        self.send_header("Content-Type", ctype or "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = _forward
    do_POST = _forward

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    host, port = LISTEN.rsplit(":", 1)
    print(f"relaying http://{LISTEN} -> {UPSTREAM}", flush=True)
    ThreadingHTTPServer((host, int(port)), Relay).serve_forever()
