# telegram-ai-bot — operating contract (for humans and agents)

This is the standing guide to how this bot is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `02-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the bot without any
other source.

## What this system is

A Telegram bot (TBXark's ChatGPT-Telegram-Workers, MIT) on Cloudflare alone,
expressed as an Orun component-native desired-state repo.

- **`infra/terraform/cloudflare-kv`** — one Workers KV namespace per deployed
  environment (`stage`, `prod`), applied by Terraform. After each apply it
  publishes a wiring document — `{app_kv_id, app_kv_title}` — as the Orun
  secret `WIRING_CLOUDFLARE_KV` on that environment.
- **`apps/bot`** — the Worker: upstream's Workers entry, bundled by wrangler.
  It answers Telegram's webhook (`POST /telegram/<token>/webhook`), serves
  the single-page app and the `/admin` Telegram Mini-App, the page's
  JSON-RPC (`POST /rpc`), the deploy's webhook binding (`POST /init/bind`)
  and `GET /health`. Bindings: `DATABASE` (the KV namespace — the global
  configuration under `config:global`, and every chat's history and state)
  and `AI` (Workers AI, the default model).
- **`packages/*`** — upstream's libraries (`@bot/*`): the bot (core), the
  model APIs and the agent over them (ai, agent), the configuration and its
  defaults (config), the Telegram client (telegram), i18n, the plugin
  templates (plugins), the shared types (types) and the single-page app
  (web, built by Vite into one HTML string). Not components: a change to one
  re-plans `apps/bot` (its `change.inputs`).
- **`tests/bot`** — every library's own tests and the Worker's, in workerd
  (vitest), verified on the `dev` rung.
- **`tooling/*`** — shared TypeScript, ESLint and Vitest configuration, and
  the wrangler renderer that turns `wrangler.template.jsonc` plus a wiring
  document into `wrangler.jsonc`.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and test, nothing deploys, and no KV
namespace exists for it (its build renders the committed fixture).

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. **The namespace before the Worker.** `cloudflare-kv` applies for the
   environment and publishes `WIRING_CLOUDFLARE_KV`. `apps/bot` declares an
   enforced `dependsOn` on it for pushes to `main`, so its deploy starts only
   after that apply — and a job resolves its secrets when it starts, so the
   document is there.
4. `apps/bot` renders `wrangler.jsonc` from that document (the real
   namespace id), builds the libraries and the bundle, and
   `wrangler deploy --env <env>` ships `telegram-ai-bot-bot-<env>`.
5. **After the deploy**, the bot's stored secrets (`TELEGRAM_TOKEN`,
   `ADMIN_ID`, `ADMIN_PASSWORD`, `TELEGRAM_SECRET_TOKEN` — whichever exist)
   are pushed to the Worker as Worker secrets (`wrangler secret bulk`), then
   the smoke runs `apps/bot/scripts/bind-webhook.mjs`: with a token it posts
   to the Worker's `POST /init/bind` (the token as a bearer) and the Worker
   sets Telegram's webhook to itself, publishes the commands and the admin
   menu button; with none it says so and does nothing. Then `/health` must
   answer `"kv":"ok"` for that environment — proof the Worker reached its
   namespace.
6. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
7. **The convergence run is the deployment.** A green run means every
   planned lane applied. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

On a pull request nothing applies or deploys: the KV root plans, the tests
run, the Worker builds and dry-deploys, and the edges in step 3 are advisory.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "bot
  converged"; probe `/health` instead.
- A change to `intent.yaml`'s `environments` maps to no component and
  redeploys nothing on its own. Land it with a change under `apps/bot`.
- `wrangler.jsonc` is generated. Edit `wrangler.template.jsonc`, run
  `pnpm run wire:fixture` and commit both; the deploy renders its own
  config from the template, so a stale committed render misleads local work.
- Stage and prod are two Workers and need two bots: one webhook per token,
  and the second bind would move the first environment's webhook.

## Secrets model

- **Brokered provider secrets**: `CLOUDFLARE_API_TOKEN` (the
  `workers-deploy` scope: Workers Scripts and KV Storage write) and
  `CLOUDFLARE_ACCOUNT_ID` — pointers minted per run from the workspace's
  Cloudflare connection. No long-lived values at rest; nothing to rotate by
  hand. The KV root and the Worker deploy use the same two.
- **Wiring**: `WIRING_CLOUDFLARE_KV` on `stage` and `prod`, written by the
  KV root's apply (lease-published), read by the Worker's build as
  `WIRING_CLOUDFLARE_KV_<ENV>`. It holds ids, not credentials.
- **The bot's own, optional**: `TELEGRAM_TOKEN` (from @BotFather),
  `ADMIN_ID` (your Telegram user id), `ADMIN_PASSWORD` (`/admin` from a plain
  browser), `TELEGRAM_SECRET_TOKEN` (Telegram's webhook secret header).
  Stored by the owner per environment with
  `orun secrets set <KEY> --org <ws> --env <env>`; each deploy pushes the
  ones that exist to the Worker as Worker secrets and deletes none
  (`wrangler secret delete` removes one). The build never sees them.
- **Model API keys** (OpenAI, Anthropic, …) are not Orun secrets: the owner
  adds a provider in `/admin`, and its key is stored in the KV configuration,
  masked in every read the admin page makes.
- Inspect by NAME only: `orun secrets list --org <ws> --project` and
  `--env stage|prod`. No tooling in this repository prints a secret value,
  and no document in `ai/context/` may contain one.

## Verifying the system

```bash
# each environment's Worker (also recorded, probed, in deployment.md):
# the KV reading, the environment, and whether a bot token is connected
curl -s https://telegram-ai-bot-bot-stage.your-workers-subdomain.workers.dev/health
curl -s https://telegram-ai-bot-bot-prod.your-workers-subdomain.workers.dev/health

# the wiring the deploys read, and workspace readiness
orun secrets list --org <ws> --env stage && orun secrets list --org <ws> --env prod
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| connect a bot | `orun secrets set TELEGRAM_TOKEN --org <ws> --env <env>` (and `ADMIN_ID`), then deploy by hand — the deploy pushes them and binds the webhook |
| change providers, models, language, plugins, commands | the bot's **Settings** menu button (the `/admin` Mini-App), or `/admin` with `ADMIN_PASSWORD` — stored in KV, no deploy |
| change the bot's code | edit `apps/bot/src` or a library under `packages/`, merge |
| change its name or source link | `apps/bot/src/identity.ts`, merge |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/bot/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| rebind the webhook | redeploy, or open `/init` and bind from there |
| add a binding (R2, D1, another KV) | a Terraform root under `infra/terraform/` that publishes `WIRING_<ROOT>`, a token in `wrangler.template.jsonc`, its fixture entry, the root in the build's `--components`, the `WIRING_<ROOT>_<ENV>` secretEnv and an enforced `dependsOn` on it in `apps/bot/component.yaml` |
| serve a custom domain | attach it to the Worker in Cloudflare (README, "Custom domain"), then replace the placeholder `telegram-ai-bot.example.com` in `intent.yaml`'s `BASE_DOMAIN` with it |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `02-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 02-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Chat history is kept in KV with no expiry, as upstream keeps it: `/new`
clears a chat, and Workers Free allows 1,000 KV writes a day. Structural
changes follow the same contract that deployed the bot: add a component
under `apps/`, `infra/` or `packages/` with a `component.yaml`, land it as a
pull request, and the convergence run applies it.
