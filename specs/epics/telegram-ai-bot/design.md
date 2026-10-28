# telegram-ai-bot — design

## What the upstream is

[ChatGPT-Telegram-Workers](https://github.com/TBXark/ChatGPT-Telegram-Workers)
(MIT, v1.10.7) is a Telegram bot written for Cloudflare Workers. One Worker:

- answers Telegram's webhook at `POST /telegram/<token>/webhook` (or
  `safehook`, through an optional `API_GUARD` service binding): commands
  (`/new`, `/model`, `/img`, `/help`, custom commands and plugin commands),
  private and group chats, replies streamed by editing the message as
  tokens arrive, images from an image model;
- calls the model API the owner chose per provider — OpenAI-compatible chat
  completions, Anthropic messages, the Responses API, or Workers AI (through
  the Worker's `AI` binding or an account token);
- keeps everything in one KV namespace bound as `DATABASE`: the global
  configuration (`config:global` — providers, their keys, settings, plugins,
  custom commands) and each chat's history and state;
- serves one single-page app (built by Vite into an HTML string the Worker
  returns) at `/`, `/help`, `/init`, `/admin` and `/interpolate`, whose data
  comes from one JSON-RPC endpoint, `POST /rpc`. `/admin` is a Telegram
  Mini-App: the owner opens it from the bot's menu button, authenticated by
  Telegram's signed `initData` (or a password from a plain browser), and
  manages providers, settings, plugins and commands there;
- reads four environment values: `TELEGRAM_TOKEN`, `ADMIN_ID`,
  `ADMIN_PASSWORD` and the optional `TELEGRAM_SECRET_TOKEN` / `PUBLIC_BASE_URL`.

Upstream deploys it with "Deploy to Cloudflare" (the KV namespace created,
the token asked for, `wrangler deploy`), then the owner opens `/init` and
binds the webhook by hand. It is a pnpm monorepo: `packages/lib/*` (types,
i18n, telegram, plugins, ai, config, agent, web, core), `packages/apps/workers`
(the entry), plus a Node/Vercel/Docker server and test packages.

## How it maps to Orun

| Upstream | Here |
|---|---|
| "Deploy to Cloudflare" creates the KV namespace | `infra/terraform/cloudflare-kv` (kv-redis-starter's root), applied per environment before the Worker deploys; the id reaches the Worker's config through the wiring document it publishes |
| `wrangler.jsonc` with `"id": "local"` filled in by hand | `apps/bot/wrangler.template.jsonc` rendered per environment by `tooling/wire` (the committed `wrangler.jsonc` is the fixture render) |
| `TELEGRAM_TOKEN`, `ADMIN_ID`, `ADMIN_PASSWORD`, `TELEGRAM_SECRET_TOKEN` set in the dashboard | optional Orun secrets (`orun secrets set … --env stage|prod`), pushed to the Worker as Worker secrets by the composition's `secrets-live` step after each deploy; none is needed for the Worker to deploy and serve |
| Open `/init` and press "bind" | the deploy's smoke binds it: `apps/bot/scripts/bind-webhook.mjs` posts to the Worker's own `/init/bind`, authenticated by the token itself, which runs upstream's bind (webhook, commands, the Mini-App menu button). With no token it is a named no-op |
| No model until the owner adds a provider in `/admin` | a built-in Workers AI provider (the `AI` binding, no key), the default for chat and images; any other provider is added in `/admin` as upstream |
| `pnpm -w run build:workers` (esbuild) | `wrangler deploy --dry-run --outdir dist` over the same entry, after turbo builds the libraries; the bundle guard (`check-bundle`) kept |
| Workers Builds deploy on push | Orun applies the namespace and deploys `<repo>-bot-{stage,prod}` on merge to `main` |
| The repository's README | `apps/bot/README.md` carries upstream's credit and licence; `apps/bot/LICENSE` is upstream's MIT licence |

## The workspace

The upstream libraries keep their layout and their code under `packages/`
(`@bot/types`, `@bot/i18n`, `@bot/telegram`, `@bot/plugins`, `@bot/ai`,
`@bot/config`, `@bot/agent`, `@bot/web`, `@bot/core`): each builds with
`tsc -b` as upstream (`@bot/web` with Vite), and their unit tests stay next
to their code. The scope is renamed from `@chatgpt-telegram-workers/*` so the
product's packages are its own. The Worker is `apps/bot` (`@app/bot`), the
upstream's `packages/apps/workers` entry plus the two routes the port adds.

Node 22 and pnpm 10.12.1 (the lanes' pins) replace upstream's Node 24, pnpm 12
and TypeScript 7: the code needs nothing either adds, and the workspace keeps
one toolchain. The Node/Vercel/Docker server, the mock packages and the
browser tests are not ported: the product runs on Workers only, and
`testing/` carries its own stand-ins.

Orun plans by component path, so `apps/bot` declares
`change.inputs: [packages/**]` — a change to a library redeploys the Worker —
and `tests/bot`, which runs every library's tests and the port's own, does
the same for `packages/**` and `apps/bot/**`.

## The default model

Upstream ships no provider: a fresh bot answers nothing until the owner adds
one in `/admin`. Here the default configuration carries one Workers AI chat
provider (`@cf/meta/llama-4-scout-17b-16e-instruct`, as rag-chatbot) and one
image provider (`@cf/black-forest-labs/flux-1-schnell`), both on the `AI`
binding with no account id or token, and both the defaults. The owner can add,
reorder or remove providers in `/admin` exactly as upstream; a saved
configuration replaces the default, as any saved configuration does.

The default language becomes English (`en`; upstream's default is `zh-cn`).

## The token and the webhook

The bot token is the one thing a product cannot invent. The build mints no
Telegram credential, so the Worker deploys without one: `/` and `/admin`
serve, and `GET /health` (added) answers `"telegram":"connect a bot token"`.
The owner stores `TELEGRAM_TOKEN` (and `ADMIN_ID`) as Orun secrets per
environment and re-runs the deploy (the console's Deploy button); the deploy
pushes them to the Worker as secrets, and its post-deploy smoke calls the
Worker's `POST /init/bind` with `Authorization: Bearer <token>`. The Worker
compares the bearer to its own token in constant time and runs upstream's
bind: `setWebhook` at its own workers.dev URL, `setMyCommands`, and the
Mini-App menu button. The token never reaches a log or a command line: the
script reads it from its environment and prints only the outcome.

Stage and prod are two Workers and need two bots (one webhook per token).

## The smoke

`/health` reads the KV namespace through the binding (the stored
configuration, or its absence) and answers `"kv":"ok"` with the environment's
name — only the Worker, bound to its namespace, can produce it. The smoke
asserts it after the webhook binding ran.

## Alternatives rejected

- **Flatten the libraries into the Worker package.** One component, but every
  upstream file moves and every import changes: an upstream release could no
  longer be compared file for file.
- **Bind the webhook from the script, calling Telegram directly.** It would
  duplicate upstream's bind (commands, menu button, the stored public URL);
  the Worker already has it.
- **A Durable Object, Queues or AI Gateway.** Upstream uses none, and Orun has
  no composition for them; nothing is dropped.
