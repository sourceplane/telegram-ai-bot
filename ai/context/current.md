# telegram-ai-bot — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a product built from it;
the two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

TBXark's ChatGPT-Telegram-Workers (MIT) — a multi-model Telegram bot with a
Telegram Mini-App admin — on one Cloudflare Worker, its upstream libraries
kept as workspace packages, Workers AI its keyless default model, its
settings and chat history in Workers KV and the namespace from Terraform. It
is packaged as an Orun baseline: `orun new --blueprint repo-blueprint.yaml`
builds a new bot in its own repository and takes it to live on stage and
prod in one landing (`01-product`: the KV namespace, then the Worker that
binds it), then records what went live (`02-docs`). The bot token connects
after the build, as an Orun secret; the next deploy binds the webhook.

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` once cut (TB4, [#5](https://github.com/sourceplane/telegram-ai-bot/pull/5)) |
| Proven live | No. Everything short of the platform is proven offline in Baseline CI: the product built in orun's staged job tree, dry-deployed with the stage document's namespace id, served by `wrangler dev`, bound to a stand-in Telegram API and answering an update through a stand-in model API, smoke-tested. No bootstrap from a tag has run against a workspace: the repository link, a real `terraform apply`, a real `wrangler deploy`, the secrets push, Telegram itself and Workers AI are unproven (risks TB-A, TB-B, TB-C) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/telegram-ai-bot/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/telegram-ai-bot/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/telegram-ai-bot/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What each component is | `apps/bot/docs/`, `infra/terraform/cloudflare-kv/docs/`, `tests/bot/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Cut `baseline-v1` with `tag.yml`; register it.
2. Bootstrap one bot from the tag against a workspace, connect a bot token,
   and record the timings (closes TB-A, TB-B, TB-C).
