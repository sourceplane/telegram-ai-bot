# telegram-ai-bot — TBXark's ChatGPT-Telegram-Workers on one Cloudflare Worker

**The upstream is a Telegram bot made for Cloudflare Workers already: one
Worker answers Telegram's webhook, keeps its settings and every chat's
history in a KV namespace, calls whichever model API the owner configured —
OpenAI-compatible, Anthropic, the Responses API or Workers AI — streams the
reply back into the chat, and serves a Telegram Mini-App where the owner
manages it all. The port keeps that code as it is, builds it in this
workspace, makes Workers AI the model a fresh bot answers with before anyone
has a vendor key, provisions the KV namespace with Terraform, hands the bot
token to the Worker as a secret and binds the webhook after each deploy — and
the baseline makes a copy of it somebody else's in one landing.**

| | |
|---|---|
| Status | In progress — TB0–TB2 on main |
| Upstream | [TBXark/ChatGPT-Telegram-Workers](https://github.com/TBXark/ChatGPT-Telegram-Workers) (MIT), v1.10.7 at `0d152e5` (2026-09-15) |
| Reference | [hono-api](https://github.com/sourceplane/hono-api) — a plain Worker on the `cloudflare-worker-turbo` composition and its bootstrap; [kv-redis-starter](https://github.com/sourceplane/kv-redis-starter) — a KV root and its wiring; [rag-chatbot](https://github.com/sourceplane/rag-chatbot) — Workers AI as the keyless default |
| Key | `TB` |

## Read in this order

1. [design.md](design.md) — what the upstream is, how each piece of its
   Cloudflare deploy maps to Orun, the workspace, the default model, the
   token and the webhook, and the alternatives rejected.
2. [implementation-plan.md](implementation-plan.md) — the milestones and
   what each one lands.
3. [risks-and-open-questions.md](risks-and-open-questions.md) — what is not
   proven, and what was accepted.
4. [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) — what shipped, and
   every departure from the upstream.

## Milestones

| Milestone | What it lands | Task |
|---|---|---|
| TB0 — the spec | the repository's intent, CI, tooling and spec index; this doc set | TB-1 |
| TB1 — the bot on Workers | the upstream libraries in `packages/`, the Worker in `apps/bot`, the default model, `/health`, the webhook binding, the tests | TB-2 |
| TB2 — the KV namespace from Terraform | `infra/terraform/cloudflare-kv` and the deploy's wait on it | TB-3 |
| TB3 — ready to instantiate | the README, the as-built status | TB-4 |
| TB4 — a baseline | the console card, the build document, the context pack and the baseline's tests | TB-5 |
