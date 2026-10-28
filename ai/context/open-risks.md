# telegram-ai-bot — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted ones, is
`specs/epics/telegram-ai-bot/risks-and-open-questions.md`; this page lists
only what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| TB-A | No live bootstrap yet: the repository created and linked, the token minted, a real `terraform apply`, the lease-published document, a real `wrangler deploy`, the secrets push and the probes are all unproven | OPEN | One bootstrap from a tag against a workspace |
| TB-B | Telegram itself: `setWebhook`, `setMyCommands`, the menu button and real updates | OPEN | One connected bot |
| TB-C | Workers AI is unproven offline (`wrangler dev` cannot reach it without an account) | OPEN | One message to a deployed bot |

Accepted, and worth knowing before you change them: TB-D (stage and prod
need two bot tokens), TB-E (the webhook URL carries the token, as upstream),
TB-F (`POST /init/bind` accepts the token as a bearer), TB-G (chat history
has no expiry in KV), TB-H (a removed secret stays on the Worker).
