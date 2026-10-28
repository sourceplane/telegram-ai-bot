import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ENV } from '@bot/config'
import worker from '@/index'
import { BOT_NAME, SOURCE_URL } from '@/identity'
import { memoryKV } from './kv'

const HOST = 'https://acme-bot-bot-stage.acme.workers.dev'
const TOKEN = '123456:AA-the-bot-token'

function call(path: string, init: RequestInit = {}, env: Record<string, unknown> = {}) {
  return worker.fetch(new Request(`${HOST}${path}`, init), { DATABASE: memoryKV(), ENVIRONMENT: 'stage', ...env })
}

beforeEach(() => {
  // ENV is the isolate's: a Worker's env never changes under it, a test's does.
  ENV.TELEGRAM_TOKEN = ''
  ENV.TELEGRAM_SECRET_TOKEN = ''
  ENV.PUBLIC_BASE_URL = ''
})
afterEach(() => vi.restoreAllMocks())

describe('the Worker', () => {
  it('serves /health before anything else', async () => {
    const r = await call('/health')
    expect(r.status).toBe(200)
    expect(await r.json()).toMatchObject({ status: 'ok', kv: 'ok', environment: 'stage', name: BOT_NAME })
  })

  it('serves the single-page app with the product name in its title', async () => {
    for (const path of ['/', '/admin', '/init', '/help']) {
      const r = await call(path)
      expect(r.status).toBe(200)
      expect(r.headers.get('content-type')).toContain('text/html')
      const page = await r.text()
      expect(page).toContain(`<title>${BOT_NAME}</title>`)
      expect(page).not.toContain('<title>ChatGPT-Telegram-Workers</title>')
    }
  })

  it("names the product and its repository in the page's data", async () => {
    const r = await call('/rpc', { method: 'POST', body: JSON.stringify({ method: 'pages.info', params: {} }) })
    const body = (await r.json()) as { result?: Record<string, unknown> } & Record<string, unknown>
    const info = (body.result ?? body) as Record<string, unknown>
    expect(info.name).toBe(BOT_NAME)
    expect(info.repoUrl).toBe(SOURCE_URL)
    expect(info.issuesUrl).toBe(`${SOURCE_URL}/issues`)
    expect(info.hasToken).toBe(false)
  })

  it('answers 404 for anything else', async () => {
    expect((await call('/no-such-page')).status).toBe(404)
  })
})

describe('POST /init/bind — the deploy binds the webhook', () => {
  it('refuses when the Worker has no token', async () => {
    const r = await call('/init/bind', { method: 'POST', headers: { Authorization: `Bearer ${TOKEN}` } })
    expect(r.status).toBe(401)
  })

  it('refuses a bearer that is not the bot token, and no bearer at all', async () => {
    const env = { TELEGRAM_TOKEN: TOKEN }
    const telegram = vi.spyOn(globalThis, 'fetch')
    for (const headers of [{ Authorization: 'Bearer 123456:AA-not-it' }, {} as Record<string, string>]) {
      const r = await call('/init/bind', { method: 'POST', headers }, env)
      expect(r.status).toBe(401)
    }
    expect(telegram).not.toHaveBeenCalled()
  })

  it("with the token, sets the webhook at the Worker's own URL, the commands and the menu button", async () => {
    const calls: { method: string; body: Record<string, unknown> }[] = []
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
      const url = new URL(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url)
      expect(url.origin).toBe('https://api.telegram.org')
      expect(url.pathname.startsWith(`/bot${TOKEN}/`)).toBe(true)
      calls.push({ method: url.pathname.split('/').pop()!, body: JSON.parse(String(init?.body ?? '{}')) })
      return Response.json({ ok: true, result: true })
    })
    const kv = memoryKV()
    const r = await worker.fetch(
      new Request(`${HOST}/init/bind`, { method: 'POST', headers: { Authorization: `Bearer ${TOKEN}` } }),
      { DATABASE: kv, ENVIRONMENT: 'stage', TELEGRAM_TOKEN: TOKEN },
    )
    expect(r.status).toBe(200)
    expect(await r.json()).toMatchObject({ ok: true, outcome: 'ok' })
    const webhook = calls.find((c) => c.method === 'setWebhook')
    expect(webhook?.body.url).toBe(`${HOST}/telegram/${TOKEN}/webhook`)
    expect(calls.some((c) => c.method === 'setMyCommands')).toBe(true)
    const menu = calls.find((c) => c.method === 'setChatMenuButton')
    expect(menu?.body).toMatchObject({ menu_button: { type: 'web_app', web_app: { url: `${HOST}/admin` } } })
    // upstream persists the detected public URL, so /admin links survive
    expect(JSON.parse(kv.data.get('config:global') ?? '{}').settings.publicBaseUrl).toBe(HOST)
  })

  it('reports a binding Telegram refused as a failure', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation(async () =>
      Response.json({ ok: false, error_code: 401, description: 'Unauthorized' }),
    )
    const r = await call('/init/bind', { method: 'POST', headers: { Authorization: `Bearer ${TOKEN}` } }, { TELEGRAM_TOKEN: TOKEN })
    expect(r.status).toBe(502)
    expect(await r.json()).toMatchObject({ ok: false, outcome: 'error' })
  })
})
