#!/usr/bin/env python3
"""A stand-in for an OpenAI-compatible chat-completions API, for the e2e.

    model-api.py <requests.jsonl> <port-file> --key <api-key> --reply <text>

Answers `POST /v1/chat/completions` for the ONE key it is given (any other
Authorization is a 401, as the real APIs answer), with <text> as the
assistant's message — as one JSON body, or as server-sent events when the
request asks to stream. `GET /v1/models` lists one model. Every accepted
request body is appended to <requests.jsonl>.
"""
import argparse, json, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ap = argparse.ArgumentParser()
ap.add_argument("requests")
ap.add_argument("port_file")
ap.add_argument("--key", required=True)
ap.add_argument("--reply", required=True)
args = ap.parse_args()
lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def json_reply(self, code, payload):
        data = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def authorized(self):
        return self.headers.get("Authorization") == f"Bearer {args.key}"

    def do_GET(self):
        if not self.authorized():
            return self.json_reply(401, {"error": {"message": "invalid api key"}})
        if self.path.rstrip("/").endswith("/models"):
            return self.json_reply(200, {"object": "list", "data": [{"id": "e2e-model", "object": "model"}]})
        self.json_reply(404, {"error": {"message": "not found"}})

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length) or b"{}")
        if not self.authorized():
            return self.json_reply(401, {"error": {"message": "invalid api key"}})
        if not self.path.rstrip("/").endswith("/chat/completions"):
            return self.json_reply(404, {"error": {"message": "not found"}})
        with lock, open(args.requests, "a") as f:
            f.write(json.dumps(body) + "\n")
        model = body.get("model", "e2e-model")
        if body.get("stream"):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            words = args.reply.split(" ")
            for i, w in enumerate(words):
                chunk = {"id": "e2e", "object": "chat.completion.chunk", "model": model,
                         "choices": [{"index": 0, "delta": {"content": w + (" " if i < len(words) - 1 else "")}, "finish_reason": None}]}
                self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
            done = {"id": "e2e", "object": "chat.completion.chunk", "model": model,
                    "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]}
            self.wfile.write(f"data: {json.dumps(done)}\n\ndata: [DONE]\n\n".encode())
            self.wfile.flush()
            return
        self.json_reply(200, {"id": "e2e", "object": "chat.completion", "model": model,
                              "choices": [{"index": 0, "message": {"role": "assistant", "content": args.reply}, "finish_reason": "stop"}],
                              "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}})


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(args.port_file, "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
