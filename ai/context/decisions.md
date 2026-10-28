# telegram-ai-bot — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | Upstream's libraries stay workspace packages (`packages/*`, scope `@bot/*`), not flattened into the Worker | An upstream release can still be compared file for file | `specs/epics/telegram-ai-bot/design.md` (The workspace) |
| 2 | `apps/bot` and `tests/bot` declare `change.inputs` on `packages/**` | Orun plans by path; the libraries are what the Worker bundles | design.md |
| 3 | A plain Worker on `cloudflare-worker-turbo`, bundled by wrangler | The upstream is a Worker already; no framework adapter | design.md (How it maps to Orun) |
| 4 | The namespace id reaches the Worker through the wiring document, rendered per environment into a one-environment config the composition deploys with `--env` | The same deploy-time render every binding in this programme uses; the composition deploys with `--env` | `apps/bot/wrangler.template.jsonc`, `apps/bot/component.yaml` |
| 5 | `apps/bot/wrangler.jsonc` is committed as the fixture render; dev renders the fixture | The deploy lane checks it exists before the build; no root applies to dev | `testing/wire.test.sh` |
| 6 | Workers AI on the `AI` binding is the default chat and image provider | A fresh bot answers with no vendor key (rag-chatbot's choice) | design.md (The default model) |
| 7 | The bot token, admin id, admin password and webhook secret are optional Orun secrets pushed to the Worker by the composition's `secrets-live` step | No provider mints a bot token; the bot deploys and serves without one | design.md (The token and the webhook) |
| 8 | The deploy's smoke binds the webhook through the Worker's own `POST /init/bind`, authenticated by the token | Upstream's bind (webhook, commands, menu button) runs once, in the Worker; the token never reaches a log | design.md, risk TB-F |
| 9 | One landing (`01-product`) then the record (`02-docs`); `bot` → `cloudflare-kv` enforced on main, advisory on a pull request | The plan, not a landing boundary, orders the namespace before the Worker | `repo-blueprint.yaml` |
| 10 | One brokered token: `workers-deploy` applies the namespace and deploys the Worker | That token covers KV Storage write (kv-redis-starter's choice) | `repo-blueprint.yaml` (`secrets`) |
| 11 | Node 22, pnpm 10.12.1 and TypeScript 5.9 instead of upstream's Node 24, pnpm 12 and TypeScript 7 | The lanes' pins; the code needs nothing newer | IMPLEMENTATION-STATUS |
| 12 | The libraries keep upstream's oxlint and their tests in workerd | Upstream's own gates; the port's code follows the workspace's ESLint | IMPLEMENTATION-STATUS |
| 13 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME` | A bootstrap cannot set a repository variable | `.github/workflows/ci.yml` |
| 14 | stack-tectonic 0.19.0 | The convention's pin; the Worker has one job per lane | `intent.yaml` |
| 15 | Component docs are generated from the manifests and checked in CI | A hand-written copy of the graph and bindings drifts silently | `tooling/catalog/gen-component-docs.py` |
| 16 | The console reads `subdomain` from the Cloudflare connection and asks for no domain | One right answer; the bot goes live on workers.dev | `blueprint.yaml` |
