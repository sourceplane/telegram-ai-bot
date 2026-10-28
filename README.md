# telegram-ai-bot

TBXark's [ChatGPT-Telegram-Workers](https://github.com/TBXark/ChatGPT-Telegram-Workers)
— a multi-model Telegram bot with a Telegram Mini-App admin — on **one
Cloudflare Worker**, its settings and chat history in a **Workers KV**
namespace and **Workers AI** its keyless default model, deployed by
[Orun](https://github.com/sourceplane/orun) to stage and prod on every merge,
and then packaged as an Orun baseline.

This is the repository's frame: `intent.yaml` (with the placeholder
workspace `ws_CHANGE_ME`, so CI plans nothing until it is linked), the Orun
CI workflow, the shared TypeScript, ESLint, wiring and catalog tooling, and
the spec index. The work is tracked as an epic under
[`specs/epics/telegram-ai-bot`](specs/epics/telegram-ai-bot/README.md).
