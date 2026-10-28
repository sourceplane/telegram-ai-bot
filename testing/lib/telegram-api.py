#!/usr/bin/env python3
"""A stand-in for Telegram's Bot API, for the e2e. Not Telegram.

    telegram-api.py <calls.jsonl> <port-file> --token <bot-token>

Answers `POST /bot<token>/<method>` as the Bot API does — `{"ok": true,
"result": …}` — for the ONE token it is given, and refuses every other token
with the Bot API's own 401 (`Unauthorized`), so a Worker that calls it with
the wrong token, or with a token it should not have, fails here as it would
fail at Telegram. Every accepted call is appended to <calls.jsonl> as
`{"method": …, "body": …}` (the token itself is never written). It binds a
free port on 127.0.0.1 and writes it to <port-file> once it listens.
"""
import argparse, json, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ap = argparse.ArgumentParser()
ap.add_argument("calls")
ap.add_argument("port_file")
ap.add_argument("--token", required=True)
args = ap.parse_args()
lock = threading.Lock()
message_id = [100]


def result_for(method, body):
    if method in ("sendMessage", "editMessageText", "sendPhoto"):
        with lock:
            message_id[0] += 1
            mid = body.get("message_id") or message_id[0]
        return {"message_id": mid, "date": int(time.time()), "chat": {"id": body.get("chat_id"), "type": "private"},
                "text": body.get("text", "")}
    if method == "getMe":
        return {"id": 1, "is_bot": True, "first_name": "e2e", "username": "e2e_bot"}
    if method == "getWebhookInfo":
        return {"url": "", "pending_update_count": 0}
    return True


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def reply(self, code, payload):
        data = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        parts = self.path.split("?")[0].strip("/").split("/")
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        if len(parts) != 2 or not parts[0].startswith("bot"):
            return self.reply(404, {"ok": False, "error_code": 404, "description": "Not Found"})
        token, method = parts[0][3:], parts[1]
        if token != args.token:
            return self.reply(401, {"ok": False, "error_code": 401, "description": "Unauthorized"})
        try:
            body = json.loads(raw or b"{}")
        except ValueError:
            body = {"_raw": raw.decode(errors="replace")[:200]}
        with lock, open(args.calls, "a") as f:
            f.write(json.dumps({"method": method, "body": body}) + "\n")
        self.reply(200, {"ok": True, "result": result_for(method, body)})

    do_GET = do_POST


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(args.port_file, "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
