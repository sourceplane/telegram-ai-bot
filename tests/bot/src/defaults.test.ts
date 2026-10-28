import { describe, expect, it } from 'vitest'
import { loadChatLLM, loadImageGen } from '@bot/agent'
import { cloneDefaultConfig, DEFAULT_WORKERS_CHAT_MODEL, DEFAULT_WORKERS_IMAGE_MODEL, ENV } from '@bot/config'

describe('Workers AI is the keyless default', () => {
  it('a fresh configuration answers chat and images with Workers AI on the AI binding', async () => {
    const runs: { model: string; input: Record<string, unknown> }[] = []
    ENV.AI_BINDING = {
      run: async (model: string, input: Record<string, unknown>) => {
        runs.push({ model, input })
        return { response: 'Hello from Workers AI' }
      },
    } as never
    const config = cloneDefaultConfig()
    expect(config.settings.language).toBe('en')
    for (const p of [...config.chatProviders, ...config.imageProviders]) {
      expect(p.apiKey).toBe('')
      expect(p.options).toEqual({})
    }

    const chat = loadChatLLM(config)
    expect(chat?.name).toBe('workers-ai')
    expect(chat?.model).toBe(DEFAULT_WORKERS_CHAT_MODEL)
    const answer = await chat!.chat([{ role: 'user', content: 'hi' }], null)
    expect(answer).toBe('Hello from Workers AI')
    expect(runs[0]?.model).toBe(DEFAULT_WORKERS_CHAT_MODEL)

    const image = loadImageGen(config)
    expect(image?.name).toBe('workers-ai-image')
    expect(image?.model).toBe(DEFAULT_WORKERS_IMAGE_MODEL)
  })

  it('without the AI binding the default provider is skipped, not an error', () => {
    ENV.AI_BINDING = null
    expect(loadChatLLM(cloneDefaultConfig())).toBeNull()
  })
})
