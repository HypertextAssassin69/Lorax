import os
import sys
import mimetypes
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

# Ensure correct MIME types for WebAssembly, JS, JSON, Fonts
mimetypes.init()
mimetypes.add_type('application/wasm', '.wasm')
mimetypes.add_type('application/javascript', '.js')
mimetypes.add_type('application/json', '.json')
mimetypes.add_type('font/ttf', '.ttf')
mimetypes.add_type('font/otf', '.otf')

WEB_DIR = os.path.join(os.path.dirname(__file__), 'build', 'web')

class NoCacheHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        if 'flutter_service_worker.js' in self.path:
            self.send_response(404)
            self.end_headers()
            return
        super().do_GET()

    def do_POST(self):
        if self.path == '/api/log':
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8', errors='ignore')
            print(f"[BROWSER BLE LOG] {body}", flush=True)
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
            return
        super().do_POST()

    def end_headers(self):
        # Prevent browser from caching white/stale responses
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        # Security headers for WebAssembly & CanvasKit
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'credentialless')
        super().end_headers()

    def log_message(self, format, *args):
        print(f"[RescueLink Web] {self.address_string()} - {format % args}", flush=True)

if __name__ == '__main__':
    port = 8080
    server = ThreadingHTTPServer(('0.0.0.0', port), NoCacheHandler)
    print(f"RescueLink Multi-Threaded Release Server running on http://localhost:{port} (serving {WEB_DIR})", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
