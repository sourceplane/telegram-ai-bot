# telegram-ai-bot — risks and open questions

| ID | Risk | State | Notes |
|---|---|---|---|
| TB-A | `baseline-v1` is not yet proven live: the namespace's apply and its wiring publish, the deploy, the secrets push and the workers.dev probes | OPEN | Proven offline in Baseline CI. One bootstrap from the tag closes it |
| TB-B | Telegram itself is unproven here: `setWebhook`, `setMyCommands`, the menu button and real updates | OPEN | Exercised against a stand-in Telegram API that refuses any token but the bot's; one connected bot closes it |
| TB-C | Workers AI is unproven offline: `wrangler dev` cannot reach it without an account | OPEN | The e2e answers through a stand-in OpenAI-compatible provider configured in `/admin`'s own RPC; the binding provider is held to upstream's unit tests |
| TB-D | Stage and prod need two bot tokens | ACCEPTED | One webhook per token: the second bind would move the first environment's webhook |
| TB-E | The webhook URL carries the token (upstream's design) | ACCEPTED | As upstream; `TELEGRAM_SECRET_TOKEN` adds Telegram's secret header check |
| TB-F | `POST /init/bind` accepts the bot token as a bearer | ACCEPTED | Whoever holds the token can bind the webhook through Telegram already; compared in constant time, and refused when the Worker has no token |
| TB-G | Chat history is kept in KV with no expiry, as upstream | ACCEPTED | `/new` clears a chat; Workers Free allows 1,000 KV writes a day |
| TB-H | A token removed from Orun stays on the Worker | ACCEPTED | The deploy pushes the secrets that exist and deletes none; `wrangler secret delete` removes one |
| TB-I | Upstream's toolchain is Node 24, pnpm 12, TypeScript 7 | ACCEPTED | Built and tested here on Node 22, pnpm 10.12.1 and TypeScript 5.8 |
