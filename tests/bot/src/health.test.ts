import { describe, expect, it } from 'vitest'
import { GLOBAL_CONFIG_KEY } from '@bot/config'
import { CONNECT_TOKEN, health } from '@/health'
import { BOT_NAME } from '@/identity'
import { memoryKV } from './kv'

async function read(r: Response) {
  return { status: r.status, body: (await r.json()) as Record<string, unknown> }
}

describe('GET /health', () => {
  it('answers ok from the KV namespace, and says to connect a token when there is none', async () => {
    const { status, body } = await read(await health({ DATABASE: memoryKV(), ENVIRONMENT: 'stage' }))
    expect(status).toBe(200)
    expect(body).toEqual({
      status: 'ok',
      name: BOT_NAME,
      environment: 'stage',
      kv: 'ok',
      configured: false,
      telegram: CONNECT_TOKEN,
    })
  })

  it('says connected once the token is a Worker secret — and never echoes it', async () => {
    const kv = memoryKV()
    kv.data.set(GLOBAL_CONFIG_KEY, '{}')
    const r = await health({ DATABASE: kv, ENVIRONMENT: 'prod', TELEGRAM_TOKEN: '123:secret-token' })
    const text = await r.clone().text()
    const { body } = await read(r)
    expect(body.telegram).toBe('connected')
    expect(body.configured).toBe(true)
    expect(text).not.toContain('secret-token')
  })

  it('fails without its KV binding', async () => {
    const { status, body } = await read(await health({ ENVIRONMENT: 'stage' }))
    expect(status).toBe(503)
    expect(body.kv).toBe('unbound')
  })

  it('fails when the namespace does not answer', async () => {
    const broken = {
      get: async () => {
        throw new Error('KV down')
      },
    } as unknown as KVNamespace
    const { status, body } = await read(await health({ DATABASE: broken, ENVIRONMENT: 'stage' }))
    expect(status).toBe(503)
    expect(body.kv).toBe('error')
  })
})
