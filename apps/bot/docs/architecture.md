# bot — architecture

Built by the turbo pipeline from `apps/bot` and deployed with wrangler.

|                    |                                    |
| ------------------ | ---------------------------------- |
| Worker config      | `apps/bot/wrangler.template.jsonc` |
| Entry              | `src/index.ts`                     |
| Compatibility date | `2026-08-04`                       |

## Bindings

| Binding    | Kind                 | Source                                  |
| ---------- | -------------------- | --------------------------------------- |
| `DATABASE` | Workers KV namespace | `app_kv_id` from `cloudflare-kv`        |
| `AI`       | Workers AI           | account-level; no resource to provision |

Identifiers marked _from_ a component are filled in at deploy time from
that component's published outputs for the environment being deployed.

## Variables

`ENVIRONMENT` — overridden per environment (`__ENV__`).

## Wiring

Resolved at deploy time from secrets the infrastructure lanes publish (names only):

- `WIRING_CLOUDFLARE_KV_PROD`
- `WIRING_CLOUDFLARE_KV_STAGE`

## Secrets resolved by the lane (names only)

- `ADMIN_ID` (optional)
- `ADMIN_PASSWORD` (optional)
- `TELEGRAM_SECRET_TOKEN` (optional)
- `TELEGRAM_TOKEN` (optional)
