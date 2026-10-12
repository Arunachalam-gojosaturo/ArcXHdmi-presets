#!/usr/bin/env python3
"""
tv-stream.py - Wireless Screen Mirroring to TV via Local Web Stream
Does NOT touch or disable NetworkManager. Works completely over existing Wi-Fi/LAN.
Works on any TV with a Web Browser (Samsung, LG, Sony, Android TV, FireTV, Roku, etc.)
"""

import http.server
import socket
import socketserver
import subprocess
import threading
import time
import os
import sys

PORT = 8080
FRAME_RATE = 20  # target fps
JPEG_QUALITY = 75

latest_frame = b""
frame_lock = threading.Lock()
running = True

def get_lan_ip():
    """Retrieve the primary local LAN IP address."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Doesn't need to be reachable, just triggers local IP routing
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

def capture_worker():
    """Continuously capture screen using grim."""
    global latest_frame, running
    cmd = ["grim", "-t", "jpeg", "-q", str(JPEG_QUALITY), "-"]
    
    interval = 1.0 / FRAME_RATE
    while running:
        t0 = time.time()
        try:
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            out, _ = p.communicate(timeout=1.0)
            if p.returncode == 0 and out:
                with frame_lock:
                    latest_frame = out
        except Exception:
            pass
        
        elapsed = time.time() - t0
        sleep_time = max(0.01, interval - elapsed)
        time.sleep(sleep_time)

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laptop Screen Mirror</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body, html {
            width: 100%;
            height: 100%;
            background-color: #000;
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        }
        #stream-container {
            width: 100vw;
            height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
        }
        #stream {
            max-width: 100%;
            max-height: 100%;
            width: auto;
            height: auto;
            object-fit: contain;
        }
        .controls {
            position: absolute;
            bottom: 24px;
            right: 24px;
            background: rgba(20, 20, 20, 0.75);
            backdrop-filter: blur(8px);
            padding: 10px 18px;
            border-radius: 30px;
            display: flex;
            gap: 12px;
            align-items: center;
            transition: opacity 0.4s ease;
            opacity: 1;
            z-index: 100;
            border: 1px solid rgba(255, 255, 255, 0.15);
        }
        .controls.hidden {
            opacity: 0;
            pointer-events: none;
        }
        button {
            background: #3b82f6;
            color: #fff;
            border: none;
            padding: 8px 16px;
            border-radius: 20px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
        }
        button:hover { background: #2563eb; }
        .status-badge {
            display: inline-block;
            width: 10px;
            height: 10px;
            background: #10b981;
            border-radius: 50%;
            margin-right: 6px;
            animation: pulse 1.5s infinite;
        }
        @keyframes pulse {
            0% { transform: scale(0.95); opacity: 0.8; }
            50% { transform: scale(1.2); opacity: 1; }
            100% { transform: scale(0.95); opacity: 0.8; }
        }
    </style>
</head>
<body>
    <div id="stream-container" onclick="toggleFullScreen()">
        <img id="stream" src="/stream.mjpg" alt="Screen Mirroring Live Stream" />
        <div class="controls" id="controls">
            <span class="status-badge"></span>
            <span style="color: #eee; font-size: 14px; margin-right: 8px;">LIVE</span>
            <button onclick="toggleFullScreen(event)">⛶ Fullscreen</button>
        </div>
    </div>

    <script>
        const controls = document.getElementById('controls');
        let hideTimeout;

        function showControls() {
            controls.classList.remove('hidden');
            clearTimeout(hideTimeout);
            hideTimeout = setTimeout(() => {
                controls.classList.add('hidden');
            }, 3000);
        }

        window.addEventListener('mousemove', showControls);
        window.addEventListener('keydown', showControls);
        showControls();

        function toggleFullScreen(e) {
            if (e) e.stopPropagation();
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen().catch(() => {});
            } else {
                if (document.exitFullscreen) {
                    document.exitFullscreen().catch(() => {});
                }
            }
        }

        // Auto-reconnect stream if stalled
        const img = document.getElementById('stream');
        img.onerror = function() {
            setTimeout(() => {
                img.src = '/stream.mjpg?t=' + new Date().getTime();
            }, 1000);
        };
    </script>
</body>
</html>
"""

class StreamingHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode('utf-8'))
        elif self.path.startswith('/stream.mjpg'):
            self.send_response(200)
            self.send_header('Age', '0')
            self.send_header('Cache-Control', 'no-cache, private')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=FRAME')
            self.end_headers()
            try:
                while running:
                    frame = None
                    with frame_lock:
                        if latest_frame:
                            frame = latest_frame
                    if frame:
                        self.wfile.write(b'--FRAME\r\n')
                        self.send_header('Content-Type', 'image/jpeg')
                        self.send_header('Content-Length', str(len(frame)))
                        self.end_headers()
                        self.wfile.write(frame)
                        self.wfile.write(b'\r\n')
                    time.sleep(1.0 / FRAME_RATE)
            except (ConnectionResetError, BrokenPipeError):
                pass
        elif self.path == '/frame.jpg':
            frame = None
            with frame_lock:
                frame = latest_frame
            if frame:
                self.send_response(200)
                self.send_header('Content-type', 'image/jpeg')
                self.send_header('Content-Length', str(len(frame)))
                self.end_headers()
                self.wfile.write(frame)
            else:
                self.send_error(503, "Frame not ready")
        else:
            self.send_error(404)

    def log_message(self, format, *args):
        # Silence verbose request logs
        return

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

def main():
    global running
    lan_ip = get_lan_ip()
    url = f"http://{lan_ip}:{PORT}"
    
    # Start screen capture thread
    t = threading.Thread(target=capture_worker, daemon=True)
    t.start()
    
    # Wait for first frame
    print("Initializing screen capture...")
    for _ in range(20):
        with frame_lock:
            if latest_frame:
                break
        time.sleep(0.1)
        
    server = ThreadedHTTPServer(('0.0.0.0', PORT), StreamingHandler)
    
    print("=" * 60)
    print("  📺 WIRELESS TV SCREEN STREAM READY")
    print("=" * 60)
    print("  Status: NetworkManager is ACTIVE (not disabled)")
    print(f"  TV URL: \033[1;32m{url}\033[0m")
    print("")
    print("  Instructions for your TV:")
    print(f"  1. Open the Web Browser app on your Smart TV / FireStick.")
    print(f"  2. Type this address: {url}")
    print("  3. Click anywhere or press 'Fullscreen' on your TV remote.")
    print("=" * 60)
    print("  Press Ctrl+C to stop streaming.")
    print("=" * 60)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping TV stream server...")
    finally:
        running = False
        server.server_close()
        print("Stopped.")

if __name__ == "__main__":
    main()
