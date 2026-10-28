// The bot's identity, written once. The home page's title and heading carry
// BOT_NAME, and its "Source code" and "Report an issue" links SOURCE_URL;
// GET /health answers with BOT_NAME, so a deploy's smoke and an operator's
// curl both see which bot answered. The Orun bootstrap that creates a product
// rewrites both to that product's, so keep them literal and on one line each.
export const BOT_NAME = "AI Telegram Bot"
export const SOURCE_URL = "https://github.com/sourceplane/telegram-ai-bot"
