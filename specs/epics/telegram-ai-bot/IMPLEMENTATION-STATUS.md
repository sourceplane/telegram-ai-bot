# telegram-ai-bot — implementation status

| Milestone | State | Landed |
|---|---|---|
| TB0 — the spec | ✅ | TB-1 (#1) |
| TB1 — the bot on Workers | ✅ | TB-2 (#2) |
| TB2 — the KV namespace from Terraform | ✅ | TB-3 (#3) |
| TB3 — ready to instantiate | ✅ | TB-4 |
| TB4 — a baseline | planned | TB-5 |

## Departures from the upstream

Upstream: TBXark/ChatGPT-Telegram-Workers v1.10.7 at `0d152e5`.

| What | Upstream | Here | Why |
|---|---|---|---|
| Layout | `packages/lib/*`, `packages/apps/workers` | `packages/*` (scope `@bot/*`), `apps/bot` | the workspace's discovery roots; the product's packages are its own |
| Not ported | `packages/apps/server` (Node, Vercel, Docker), `packages/test/*` (mocks, browser tests) | — | the product runs on Workers only; `testing/` carries its own stand-ins |
| Toolchain | Node 24, pnpm 12, TypeScript 7, `@types/node` 26 | Node 22, pnpm 10.12.1, TypeScript 5.9 (`@types/node` 26 kept for the libraries' types) | the lanes' pins; the code needs nothing newer |
| Lint | oxlint at the root | oxlint per library (`oxlint src`), ESLint for `apps/bot` and `tests/bot` | the libraries keep upstream's linter; the port's code follows the workspace's |
| Tests | `vitest run` per library in workerd (`vitest.config.shared.ts`) | the same, from `tooling/vitest/shared.mjs`; `tests/bot` runs every library's tests and the port's own | one component runs them on a pull request |
| Example plugins | `plugins/*.json` at the root | `packages/plugins/src/examples/` | inside the package whose test reads them |
| Build | esbuild script + `check-bundle.ts` | `wrangler deploy --dry-run --outdir dist` + `scripts/check-bundle.mjs` | wrangler bundles what it deploys; the guard is upstream's |
| Default model | none (every provider added in `/admin`) | Workers AI on the `AI` binding for chat (`@cf/meta/llama-4-scout-17b-16e-instruct`) and images (`@cf/black-forest-labs/flux-1-schnell`), both the defaults | a fresh bot answers with no vendor key |
| Default language | `zh-cn` | `en` | the product's audience; `/admin` changes it |
| Three upstream tests | assert the empty default | assert the Workers AI default | the deliberate default above |
| Page identity | "ChatGPT-Telegram-Workers"; source and issue links to upstream | the product's name in `<title>` and the heading; source and issue links to the product's repository; the documentation link stays upstream's | a product is its owner's; the credit is in `apps/bot/README.md` and `LICENSE` |
| The token notice on `/` | "add it to your environment" | "store it as the environment's Orun secret and redeploy" | how this product receives it |
| Webhook binding | the owner opens `/init` and presses bind | also `POST /init/bind`, authenticated by the token, which the deploy's smoke calls | a deploy with a token comes up bound |
| `/health` | — | added | the deploy's smoke and the bootstrap's probe |
| `wrangler dev` | remote Workers AI by default | `dev` (with an account) and `dev:local` (`--local`, no account) | a local run without a Cloudflare login |
| KV namespace | "Deploy to Cloudflare" creates it; CLI deploys fill its id in by hand | `infra/terraform/cloudflare-kv` per environment (`<prefix><repo>-app-kv-<env>`), adopting one of the same title; its id rendered into the Worker's config from the wiring document, the deploy waiting on the apply | provisioned and ordered by the product's own plan |
