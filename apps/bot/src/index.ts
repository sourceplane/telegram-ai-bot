import { createApp, ENV } from '@bot/core'
import { health, type HealthEnv } from './health'
import { BOT_NAME, SOURCE_URL } from './identity'

// The Worker: upstream's Cloudflare Workers entry (packages/apps/workers),
// configured from the Worker's env on every request — the DATABASE KV
// namespace, the AI binding, and the bot's secrets — with the product's own
// name and repository on its pages, and one route the port adds in front of
// it: GET /health. Everything else — the webhook at /telegram/<token>/webhook,
// the pages, /rpc and the deploy's POST /init/bind — is upstream's app.
const app = createApp({
  name: BOT_NAME,
  repoUrl: SOURCE_URL,
  onRequest: (env) => {
    ENV.merge((env as Record<string, unknown>) ?? {})
  },
})

export default {
  async fetch(request: Request, env: HealthEnv): Promise<Response> {
    const { pathname } = new URL(request.url)
    if (request.method === 'GET' && pathname === '/health') {
      return health(env)
    }
    return app.fetch(request, env)
  },
} satisfies ExportedHandler<HealthEnv>
