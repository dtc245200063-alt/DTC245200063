#!/usr/bin/env python3
"""
Alert Sink Service for De3 DTC245200063
Receives Grafana Webhook alerts, logs to stdout and saves to persistent volume.
"""
import http.server
import json
import sys
import datetime
import os

LOG_FILE = "/data/alerts.log"
os.makedirs("/data", exist_ok=True)

class AlertWebhookHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length).decode('utf-8')
            
            now_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            log_entry = f"[{now_str}] [ALERT_SINK] RECEIVED_WEBHOOK: {post_data}\n"
            
            # Print to stdout for Docker and Promtail
            sys.stdout.write(log_entry)
            sys.stdout.flush()
            
            # Append to file
            with open(LOG_FILE, "a", encoding="utf-8") as f:
                f.write(log_entry)
                
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status":"received"}')
        except Exception as e:
            sys.stderr.write(f"Error handling webhook: {e}\n")
            sys.stderr.flush()
            self.send_response(500)
            self.end_headers()

    def do_GET(self):
        if self.path == '/health' or self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'alert-sink is healthy\n')
        elif self.path == '/alerts':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            if os.path.exists(LOG_FILE):
                with open(LOG_FILE, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.wfile.write(b'')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress default server log to keep container logs focused
        pass

if __name__ == '__main__':
    port = 9099
    server = http.server.ThreadingHTTPServer(('0.0.0.0', port), AlertWebhookHandler)
    sys.stdout.write(f"Alert Sink listening on port {port}...\n")
    sys.stdout.flush()
    server.serve_forever()
