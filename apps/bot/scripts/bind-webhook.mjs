#!/usr/bin/env node
// The deploy's webhook binding — run by the component's smoke, which is the
// step after the deploy and the secrets push.
//
// The bot token is an optional Orun secret (TELEGRAM_TOKEN). The deploy job
// has it in its environment when the owner stored one, and has already pushed
// it to the Worker as a secret. This posts to the Worker's own
// POST /init/bind with the token as a bearer, and the Worker runs upstream's
// bind: setWebhook at its own URL, setMyCommands, the Mini-App menu button.
// With no token it says so and exits 0: a fresh bot deploys and serves
// before its owner has created a bot.
//
// The token is never printed, never on a command line, never in a URL this
// logs: it travels in a header to the Worker, over HTTPS.
//
//   node scripts/bind-webhook.mjs <worker-url>
const base = (process.argv[2] ?? "").replace(/\/+$/, "");
if (!/^https?:\/\//.test(base)) {
  console.error("usage: bind-webhook.mjs <worker-url>");
  process.exit(2);
}
const token = (process.env.TELEGRAM_TOKEN ?? "").trim();
if (!token) {
  console.log(
    `bind-webhook: no TELEGRAM_TOKEN stored for ${process.env.ORUN_ENVIRONMENT ?? "this environment"} — ` +
      "the webhook is not bound (connect a bot token: store it with `orun secrets set TELEGRAM_TOKEN`, then redeploy)",
  );
  process.exit(0);
}

let response;
try {
  response = await fetch(`${base}/init/bind`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    signal: AbortSignal.timeout(30_000),
  });
} catch (e) {
  console.error(`bind-webhook: ${base}/init/bind did not answer (${e.name})`);
  process.exit(1);
}
let body = {};
try {
  body = await response.json();
} catch {
  // reported below by status
}
const outcome = body.outcome ?? `HTTP ${response.status}`;
if (response.ok && body.ok) {
  console.log(`bind-webhook: the webhook is bound to ${base} (commands and the admin menu button published)`);
  process.exit(0);
}
// Telegram's own description, when it gave one, says what is wrong (a revoked
// token, a URL it refused). It never contains the token.
const description = body.result?.webhook?.description ?? body.message ?? "";
console.error(`bind-webhook: binding failed — ${outcome}${description ? `: ${description}` : ""}`);
process.exit(1);
