from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json

class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: bytes, ctype: str = "text/plain") -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        self.wfile.flush()

    def do_GET(self):
        print("Webhook health check received", flush=True)
        self._send(200, b"UP")

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(length).decode("utf-8")

        print("\n=== WEBHOOK RECEIVED ===", flush=True)
        print("Path:", self.path, flush=True)
        print("Headers:", dict(self.headers), flush=True)
        print("Body:", raw_body, flush=True)

        try:
            parsed = json.loads(raw_body)
            print("Parsed JSON:", json.dumps(parsed, indent=2), flush=True)
        except Exception:
            print("Body is not valid JSON", flush=True)

        self._send(200, b"OK")

    def log_message(self, format, *args):
        return

if __name__ == "__main__":
    print("Webhook listener running on 0.0.0.0:8099", flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8099), Handler).serve_forever()
