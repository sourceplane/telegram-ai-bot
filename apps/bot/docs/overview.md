# bot

The Telegram bot (upstream's Workers entry over its libraries, one plain Cloudflare Worker per environment)

A Cloudflare Worker, deployed per environment by its CI lane.

|              |                                                                                                                    |
| ------------ | ------------------------------------------------------------------------------------------------------------------ |
| Type         | `cloudflare-worker-turbo`                                                                                          |
| Source       | `apps/bot`                                                                                                         |
| Package      | `@app/bot`                                                                                                         |
| Environments | `dev`: `verify` · `stage`: `verify`, `deploy` on a push to `main` · `prod`: `verify`, `deploy` on a push to `main` |

## Depends on

- **cloudflare-kv** — Provisions the Cloudflare KV namespace the bot binds as DATABASE (stage and prod)

## Depended on by

- (none)
