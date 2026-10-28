# telegram-ai-bot

TBXark's [ChatGPT-Telegram-Workers](https://github.com/TBXark/ChatGPT-Telegram-Workers)
— a Telegram bot that answers in private and group chats with the model API
you choose, streams its replies, draws images, runs custom commands and
plugins, and is managed from a Telegram Mini-App — running as **one
Cloudflare Worker**, its settings and every chat's history in a **Workers
KV** namespace Terraform provisions per environment through
[Orun](https://github.com/sourceplane/orun), and **Workers AI** the model it
answers with before you have any vendor key, through the Worker's own `AI`
binding.

The upstream was written for Workers already, so its code is the code: its
libraries are workspace packages here, built and tested as upstream builds
and tests them. What the port adds is the deploy: the namespace from
Terraform, the bot token handed to the Worker as a secret, Telegram's
webhook bound to the Worker after each deploy, a `/health` route the deploy
smoke-tests, and Workers AI as the default. See
[`specs/epics/telegram-ai-bot`](specs/epics/telegram-ai-bot/README.md) for
the design, the milestones and the as-built status.

## What is here

| Surface | Where |
|---|---|
| The Worker — upstream's entry, `/health`, the deploy's webhook binding | `apps/bot/src` |
| The bot's name and repository (the rename's seam) | `apps/bot/src/identity.ts` |
| The bot: commands, chats, streaming, history | `packages/core` (upstream) |
| The model APIs (OpenAI-compatible, Anthropic, Responses, Workers AI) and the agent over them | `packages/ai`, `packages/agent` (upstream) |
| The configuration, its defaults (Workers AI) and its KV store | `packages/config` |
| The Telegram API client, i18n, the plugin templates, the shared types | `packages/telegram`, `packages/i18n`, `packages/plugins`, `packages/types` (upstream) |
| The single-page app and the `/admin` Mini-App | `packages/web` (upstream; Vite, inlined into one HTML string) |
| Workers build, bindings and deploy contract | `apps/bot/wrangler.template.jsonc` + `wiring.fixture.json` (→ the committed `wrangler.jsonc`), `component.yaml`, `scripts/` |
| The KV namespace (stage, prod) | `infra/terraform/cloudflare-kv` |
| Tests | `tests/bot` (every library's tests and the port's own, in workerd) |

## Getting started

```bash
pnpm install
pnpm run wire:fixture   # render apps/bot/wrangler.jsonc from the offline fixture
pnpm typecheck
pnpm lint
pnpm test
pnpm build              # the libraries, then wrangler deploy --dry-run → apps/bot/dist
```

```bash
pnpm --filter @app/bot dev:local   # http://localhost:8787 — local KV; no account, so no Workers AI
pnpm --filter @app/bot dev         # the same with Workers AI (after `wrangler login`)
curl http://localhost:8787/health  # {"status":"ok",…,"kv":"ok","telegram":"connect a bot token"}
```

Copy `apps/bot/.dev.vars.example` to `apps/bot/.dev.vars` to give the local
Worker a bot token; Telegram needs a public HTTPS URL to deliver updates, so
a local bot is reached through a tunnel (`wrangler dev --tunnel`).

## Connecting a bot

The Worker deploys and serves with no bot at all: `/` and `/admin` answer,
and `/health` says `"telegram":"connect a bot token"`. To give it one, per
environment (stage and prod are two Workers and need two bots — one webhook
per token):

1. Create the bot with [@BotFather](https://t.me/BotFather) (`/newbot`) and
   copy its token; find your own Telegram user id with
   [@userinfobot](https://t.me/userinfobot).
2. Store them as the environment's Orun secrets:

   ```bash
   orun secrets set TELEGRAM_TOKEN --env stage    # the token from @BotFather
   orun secrets set ADMIN_ID --env stage          # your Telegram user id
   orun secrets set ADMIN_PASSWORD --env stage    # optional: /admin from a plain browser
   orun secrets set TELEGRAM_SECRET_TOKEN --env stage   # optional: Telegram's webhook secret header
   ```

3. Redeploy the environment (Orunbase's **Deploy** button, or **Run
   workflow** — below). The deploy pushes the secrets to the Worker, then
   binds the webhook: the Worker sets Telegram's webhook to itself,
   publishes the bot's commands, and puts the admin Mini-App on the chat's
   menu button.
4. Message your bot. It answers with Workers AI; open **Settings** (the menu
   button) to add OpenAI, Anthropic, Groq, DeepSeek or any OpenAI-compatible
   API, pick models, change the language, and add plugins and commands —
   upstream's [documentation](https://github.com/TBXark/ChatGPT-Telegram-Workers/tree/master/doc/en)
   covers each.

## How the namespace is wired

The Worker binds the namespace as `DATABASE` (upstream's name). Its id is
never hand-written: `apps/bot/wrangler.template.jsonc` names it as a wiring
token, and `wrangler.jsonc` is that template rendered — from
`wiring.fixture.json` (placeholder ids) for local work and verification, and
on every deploy from the document the `cloudflare-kv` Terraform root
publishes after its apply (`WIRING_CLOUDFLARE_KV`, per environment). Edit the
template, then `pnpm run wire:fixture` and commit the render with it.

## How it deploys

Merges to `main` converge through Orun: `.github/workflows/ci.yml` plans the
changed components and runs each lane against the workspace in
`intent.yaml`. The KV namespace applies first, then the Worker builds with
that environment's namespace id and deploys — to `stage`, then to `prod`
once stage has converged on the same commit; `dev` only verifies. The Worker
is `telegram-ai-bot-bot-<env>` on your account's workers.dev subdomain.
After each deploy the bot's stored secrets are pushed to it, its webhook is
bound when it has a token, and `/health` must answer `"kv":"ok"` for that
environment. A pull request runs the verify lanes, with nothing applied or
deployed: the namespace planned, the tests run, the Worker built and
dry-deployed per environment.

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare token and account id are brokered per run from the workspace's
Cloudflare connection; the namespace ids and the bot's secrets travel as
Orun secrets. Nothing provider-shaped is stored in the repository or in
GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment with nothing changed — after storing
the bot's token, say. A component with nothing to run in that environment (a
test suite in `prod`) is left out with a notice.

## How it maps to the upstream's Cloudflare deploy

| Upstream | Here |
|---|---|
| "Deploy to Cloudflare" creates the KV namespace | `infra/terraform/cloudflare-kv`, applied by Orun per environment before the Worker deploys |
| `wrangler.jsonc` with the namespace id filled in by hand | `apps/bot/wrangler.template.jsonc`, rendered per environment from the root's wiring document |
| `TELEGRAM_TOKEN`, `ADMIN_ID`, `ADMIN_PASSWORD` in the dashboard | optional Orun secrets per environment, pushed to the Worker as Worker secrets after each deploy |
| Open `/init` and press "bind" | the deploy binds the webhook itself (`scripts/bind-webhook.mjs` → the Worker's `POST /init/bind`); `/init` still works |
| No model until a provider is added in `/admin` | Workers AI on the `AI` binding, the default for chat and images, no key |
| Workers Builds on push | Orun applies the namespace and deploys `<repo>-bot-{stage,prod}` on merge to `main` |
| `pnpm -w run build:workers` (esbuild) | `wrangler deploy --dry-run` after turbo builds the libraries; upstream's bundle guard kept |
| Node, Vercel and Docker deploys | not ported: Workers only |

## Custom domain

The bot answers on workers.dev from its first deploy. To serve it on your
own domain, add the domain to the Cloudflare account the bot deploys into
and attach it to the Worker (dashboard → Workers & Pages →
`telegram-ai-bot-bot-prod` → Settings → Domains & Routes → Add → Custom
domain), then set the public base URL to it in `/admin`'s settings and bind
the webhook again from `/init` (or redeploy), so Telegram and the admin
links use it. The repository names the
domain in one place, `BASE_DOMAIN` in `intent.yaml`, which it was born with
as the reserved placeholder `telegram-ai-bot.example.com`. Replace it with
your domain in the same change that records it.

## Credit and licence

The bot is [ChatGPT-Telegram-Workers](https://github.com/TBXark/ChatGPT-Telegram-Workers)
by [TBXark](https://github.com/TBXark) and its contributors, released under
the MIT licence ([`apps/bot/LICENSE`](apps/bot/LICENSE)), which a product
built from this repository keeps.
