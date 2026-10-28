import type { AppConfig, AppSettings } from './types';

export const DEFAULT_SETTINGS: AppSettings = {
    // telegram-ai-bot: English by default (upstream: 'zh-cn'); /admin changes it.
    language: 'en',
    updateBranch: 'master',
    publicBaseUrl: '',
    telegramApiDomain: 'https://api.telegram.org',
    defaultParseMode: 'Markdown',
    systemInitMessage: null,
    streamMode: true,
    chatCompleteApiTimeout: 0,
    maxOutputTokens: 0,
    telegramMinStreamInterval: 0,
    telegramPhotoSizeOffset: 1,
    telegramImageTransferMode: 'base64',
    modelListColumns: 1,

    allowAllUsers: false,
    allowedUserIds: [],
    allowedGroupIds: [],
    groupChatBotEnable: true,
    groupChatBotShareMode: true,

    autoTrimHistory: true,
    maxHistoryLength: 20,
    maxTokenLength: -1,
    historyImagePlaceholder: null,

    showReplyButton: false,
    extraMessageContext: false,
    extraMessageMediaCompatible: ['image'],
    hideCommandButtons: [],
    safeMode: true,
    debugMode: false,
    devMode: false,
};

/**
 * telegram-ai-bot: the model a fresh bot answers with. Upstream ships no
 * provider — nothing answers until the owner adds one in /admin. Here the
 * default configuration carries Workers AI on the Worker's own `AI` binding
 * (no account id, no token, no vendor key) for chat and for images, both the
 * defaults. Any configuration saved from /admin replaces this one, as upstream.
 */
export const DEFAULT_WORKERS_CHAT_MODEL = '@cf/meta/llama-4-scout-17b-16e-instruct';
export const DEFAULT_WORKERS_IMAGE_MODEL = '@cf/black-forest-labs/flux-1-schnell';

export const DEFAULT_CONFIG: AppConfig = {
    version: 1,
    defaultChatProvider: 'workers-ai',
    defaultImageProvider: 'workers-ai-image',
    settings: { ...DEFAULT_SETTINGS },
    chatProviders: [
        {
            id: 'workers-ai',
            protocol: 'workers',
            label: 'Cloudflare Workers AI',
            enabled: true,
            apiKey: '',
            baseUrl: '',
            model: DEFAULT_WORKERS_CHAT_MODEL,
            models: [DEFAULT_WORKERS_CHAT_MODEL],
            extraParams: {},
            options: {},
        },
    ],
    imageProviders: [
        {
            id: 'workers-ai-image',
            protocol: 'workers',
            label: 'Cloudflare Workers AI',
            enabled: true,
            apiKey: '',
            baseUrl: '',
            model: DEFAULT_WORKERS_IMAGE_MODEL,
            models: [DEFAULT_WORKERS_IMAGE_MODEL],
            extraParams: {},
            options: {},
        },
    ],
    plugins: [],
    customCommands: [],
};

/** 默认配置的独立副本:避免调用方原地修改污染模块级常量 */
export function cloneDefaultConfig(): AppConfig {
    return structuredClone(DEFAULT_CONFIG);
}
