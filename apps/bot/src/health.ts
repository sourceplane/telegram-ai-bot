import { GLOBAL_CONFIG_KEY } from '@bot/config'
import { BOT_NAME } from './identity'

// What the Worker is given: the KV namespace the wiring rendered into its
// config, the per-environment name, and — once its owner stores it — the bot
// token (a Worker secret the deploy pushes).
export type HealthEnv = {
  DATABASE?: KVNamespace
  ENVIRONMENT?: string
  TELEGRAM_TOKEN?: string
}

export const CONNECT_TOKEN = 'connect a bot token'

/**
 * GET /health — the operational contract the deploy's smoke and the
 * bootstrap's probe read. It reads the KV namespace through the binding
 * (the stored configuration, or its absence), so `"kv":"ok"` is something
 * only this Worker, bound to its namespace, can answer; it names the bot and
 * the environment whose config it runs, and whether a bot token is connected
 * — never the token itself.
 */
export async function health(env: HealthEnv): Promise<Response> {
  const environment = env.ENVIRONMENT ?? 'unknown'
  const telegram = env.TELEGRAM_TOKEN ? 'connected' : CONNECT_TOKEN
  if (!env.DATABASE) {
    return Response.json(
      { status: 'error', name: BOT_NAME, environment, kv: 'unbound', telegram },
      { status: 503 },
    )
  }
  try {
    const stored = await env.DATABASE.get(GLOBAL_CONFIG_KEY)
    return Response.json({
      status: 'ok',
      name: BOT_NAME,
      environment,
      kv: 'ok',
      configured: stored !== null,
      telegram,
    })
  } catch (e) {
    return Response.json(
      { status: 'error', name: BOT_NAME, environment, kv: 'error', telegram, error: (e as Error).message },
      { status: 503 },
    )
  }
}
