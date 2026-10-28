# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`telegram-ai-bot/`](./telegram-ai-bot/) | **TB** | In progress (TB1) | TBXark's ChatGPT-Telegram-Workers — a multi-model Telegram bot with a Telegram Mini-App admin — on one Cloudflare Worker, Workers AI its keyless default model and its settings and history in Workers KV, and an Orun baseline that instantiates it in one landing (TB4) |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
