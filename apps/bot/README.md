# apps/bot — the Worker

[ChatGPT-Telegram-Workers](https://github.com/TBXark/ChatGPT-Telegram-Workers)
by [TBXark](https://github.com/TBXark) and its contributors, MIT
([LICENSE](LICENSE)): upstream's Cloudflare Workers entry
(`packages/apps/workers`), over upstream's libraries in [`packages/`](../../packages),
with the product's name and repository on its pages and one route in front.

| Route | What answers |
|---|---|
| `POST /telegram/<token>/webhook` (`/safehook`) | Telegram's updates — upstream |
| `GET /`, `/help`, `/init`, `/admin`, `/interpolate` | upstream's single-page app (`@bot/web`); `/admin` is the Telegram Mini-App |
| `POST /rpc` | the page's JSON-RPC — upstream |
| `POST /init/bind` | the deploy's webhook binding: `Authorization: Bearer <bot token>`, then upstream's bind (webhook, commands, menu button) — added |
| `GET /health` | the KV namespace read through `DATABASE`, the environment, whether a token is connected — added |

Bindings: `DATABASE` (Workers KV, from the `cloudflare-kv` root's wiring),
`AI` (Workers AI). Secrets, all optional: `TELEGRAM_TOKEN`, `ADMIN_ID`,
`ADMIN_PASSWORD`, `TELEGRAM_SECRET_TOKEN`.

```bash
pnpm --filter @app/bot dev:local   # wrangler dev, no account: local KV, no Workers AI
pnpm --filter @app/bot dev         # wrangler dev with Workers AI (needs `wrangler login`)
pnpm --filter @app/bot build       # wrangler deploy --dry-run → dist/, then the bundle guard
```

Upstream's documentation — the commands, the configuration, the plugin
system — is at
[`doc/en`](https://github.com/TBXark/ChatGPT-Telegram-Workers/tree/master/doc/en).
