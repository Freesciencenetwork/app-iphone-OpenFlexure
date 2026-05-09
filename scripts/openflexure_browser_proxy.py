#!/usr/bin/env python3
"""Debuggable localhost proxy for the OpenFlexure web UI.

This is useful when the microscope is reachable from Terminal but the browser
cannot directly open the link-local address, for example:

    python3 scripts/openflexure_browser_proxy.py
    open http://127.0.0.1:5502/?fresh=stream

The proxy:
- forwards browser requests to the OpenFlexure server
- rewrites absolute OpenFlexure URLs in HTML/JSON/JS/CSS responses
- strips cache validators to avoid browser-triggered 304 errors
- streams MJPEG without buffering the whole response
- optionally injects localStorage settings so the web preview is not disabled
  just because the page is served from 127.0.0.1
"""

from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import sys
import urllib.error
import urllib.request


HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
    "content-length",
}

CACHE_REQUEST_HEADERS = {
    "if-none-match",
    "if-modified-since",
    "if-range",
    "cache-control",
    "pragma",
}

CACHE_RESPONSE_HEADERS = {
    "etag",
    "last-modified",
    "expires",
    "cache-control",
}


class OpenFlexureProxy(BaseHTTPRequestHandler):
    target_base = "http://169.254.103.118:5000"
    public_base = "http://127.0.0.1:5502"
    inject_stream_settings = True
    verbose = False

    def do_GET(self) -> None:
        self.forward()

    def do_HEAD(self) -> None:
        self.forward()

    def do_POST(self) -> None:
        self.forward()

    def do_PUT(self) -> None:
        self.forward()

    def do_DELETE(self) -> None:
        self.forward()

    def do_OPTIONS(self) -> None:
        self.forward()

    @classmethod
    def target_hostport(cls) -> bytes:
        return cls.target_base.replace("http://", "").replace("https://", "").encode()

    @classmethod
    def public_hostport(cls) -> bytes:
        return cls.public_base.replace("http://", "").replace("https://", "").encode()

    @classmethod
    def injection(cls) -> bytes:
        if not cls.inject_stream_settings:
            return b""
        return (
            b'<script>'
            b'localStorage.setItem("disableStream","false");'
            b'localStorage.setItem("autoGpuPreview","false");'
            b'localStorage.setItem("trackWindow","false");'
            b'</script>'
        )

    def forward(self) -> None:
        body = self.read_request_body()
        target_url = self.target_base.rstrip("/") + self.path
        request = urllib.request.Request(target_url, data=body, method=self.command)
        request.add_header("Cache-Control", "no-cache")

        for key, value in self.headers.items():
            lower = key.lower()
            if lower in HOP_BY_HOP_HEADERS or lower in CACHE_REQUEST_HEADERS or lower == "host":
                continue
            request.add_header(key, value)

        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                self.forward_response(response)
        except urllib.error.HTTPError as error:
            self.forward_http_error(error, target_url)
        except BrokenPipeError:
            pass
        except Exception as error:
            self.send_proxy_error(target_url, error)

    def read_request_body(self) -> bytes | None:
        content_length = self.headers.get("Content-Length")
        if not content_length:
            return None
        return self.rfile.read(int(content_length))

    def is_streaming_response(self, response: urllib.response.addinfourl) -> bool:
        content_type = response.headers.get("Content-Type", "").lower()
        path = self.path.split("?", 1)[0]
        return (
            self.command != "HEAD"
            and (
                "multipart/x-mixed-replace" in content_type
                or path.endswith("/api/v2/streams/mjpeg")
            )
        )

    def forward_response(self, response: urllib.response.addinfourl) -> None:
        self.send_response(response.status)

        if self.is_streaming_response(response):
            self.copy_response_headers(response)
            self.end_headers()
            self.stream_body(response)
            return

        data = b"" if self.command == "HEAD" else response.read()
        data = self.rewrite_body(data, response.headers.get("Content-Type", ""))
        self.copy_response_headers(response, content_length=len(data))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def forward_http_error(self, error: urllib.error.HTTPError, target_url: str) -> None:
        if self.verbose:
            print(f"{self.command} {target_url} -> HTTP {error.code}", file=sys.stderr)

        data = b"" if self.command == "HEAD" else error.read()
        data = self.rewrite_body(data, error.headers.get("Content-Type", ""))

        status = 200 if error.code == 304 else error.code
        self.send_response(status)
        self.copy_response_headers(error, content_length=len(data))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def copy_response_headers(
        self,
        response: urllib.response.addinfourl | urllib.error.HTTPError,
        content_length: int | None = None,
    ) -> None:
        for key, value in response.headers.items():
            lower = key.lower()
            if lower in HOP_BY_HOP_HEADERS or lower in CACHE_RESPONSE_HEADERS:
                continue
            self.send_header(key, value)

        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        if content_length is not None:
            self.send_header("Content-Length", str(content_length))

    def rewrite_body(self, data: bytes, content_type: str) -> bytes:
        if not data:
            return data

        data = data.replace(self.target_base.encode(), self.public_base.encode())
        data = data.replace(self.target_hostport(), self.public_hostport())

        if self.inject_stream_settings and "text/html" in content_type.lower():
            injection = self.injection()
            if b"<head>" in data and injection not in data:
                data = data.replace(b"<head>", b"<head>" + injection, 1)

        return data

    def stream_body(self, response: urllib.response.addinfourl) -> None:
        while True:
            chunk = response.read(64 * 1024)
            if not chunk:
                break
            self.wfile.write(chunk)
            self.wfile.flush()

    def send_proxy_error(self, target_url: str, error: Exception) -> None:
        message = f"Proxy could not reach {target_url}: {error}\n".encode()
        self.send_response(502)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(message)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(message)

    def log_message(self, fmt: str, *args: object) -> None:
        if self.verbose:
            super().log_message(fmt, *args)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Proxy the OpenFlexure web UI for browsers.")
    parser.add_argument("--target", default="http://169.254.103.118:5000")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=5502, type=int)
    parser.add_argument("--public-base", help="Public base URL advertised to the browser.")
    parser.add_argument(
        "--no-stream-injection",
        action="store_true",
        help="Do not inject localStorage settings that enable the embedded web stream.",
    )
    parser.add_argument("--verbose", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    public_base = args.public_base or f"http://{args.host}:{args.port}"

    OpenFlexureProxy.target_base = args.target.rstrip("/")
    OpenFlexureProxy.public_base = public_base.rstrip("/")
    OpenFlexureProxy.inject_stream_settings = not args.no_stream_injection
    OpenFlexureProxy.verbose = args.verbose

    server = ThreadingHTTPServer((args.host, args.port), OpenFlexureProxy)
    print(f"OpenFlexure proxy: {OpenFlexureProxy.public_base}/ -> {OpenFlexureProxy.target_base}/")
    print("Open this URL:")
    print(f"  {OpenFlexureProxy.public_base}/?fresh=stream")
    print("Press Ctrl-C to stop.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping proxy.")
    finally:
        server.server_close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
