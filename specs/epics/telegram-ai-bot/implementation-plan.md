# telegram-ai-bot — implementation plan

## TB0 — the spec (TB-1)

The repository's frame on top of its first README commit: hono-api's intent
(with kv-redis-starter's per-environment Terraform parameters), CI (turso-starter's
`ci.yml`, byte for byte but for the one credential comment), the shared
TypeScript, ESLint, wiring and catalog tooling, the pnpm workspace and turbo
pipeline, the spec index; this doc set and the five task contracts.

## TB1 — the bot on Workers (TB-2)

1. The upstream libraries (at `0d152e5`) into `packages/`, scope `@bot/*`,
   built by `tsc -b` (`@bot/web` by Vite into its HTML string module), their
   tests beside them.
2. `apps/bot`: the upstream Workers entry, `/health`, `/init/bind`; the
   wrangler template (the `DATABASE` KV namespace from the `cloudflare-kv`
   wiring, the `AI` binding, per-environment vars), the fixture and its
   committed render; the build (`wrangler deploy --dry-run`) and the bundle
   guard; the component on `cloudflare-worker-turbo` with the optional
   secrets and the post-deploy binding.
3. The defaults: a Workers AI chat and image provider, English.
4. `tests/bot`: every library's tests, and the port's own — the health route
   with and without a token, the bind route's authentication, the default
   providers, the bind script.

## TB2 — the KV namespace from Terraform (TB-3)

kv-redis-starter's `infra/terraform/cloudflare-kv` root, renamed, adopting a
namespace of the same title; `apps/bot` waits on it (enforced on a push to
main, advisory on a pull request) and resolves its wiring document per
environment.

## TB3 — ready to instantiate (TB-4)

The README: what it is, how it runs, tests, connects a bot and deploys, how
each upstream piece maps here; the as-built status.

## TB4 — a baseline (TB-5)

The card (one Cloudflare provider; the bot token connected after the build),
the build document (one landing, then the record), the identity and the rename
seam (`BOT_NAME`), the context pack, the deployment record probing `/health`,
and the baseline's tests: contract tiers, generated component docs, the leak
gate, placement, the offline bootstrap, and the e2e — the stage lanes in
staged job trees, the Worker served with no token, then with one, bound and
answering an update against stand-in Telegram and model APIs. Then
`baseline-v1`.
