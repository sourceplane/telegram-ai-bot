import { ENV } from '@bot/config';
import { type App, createApp } from './app';

export * from './app';
export * from './bot';
export * from './rpc';
// 兼容旧导出面:core 曾包含 agent/config/i18n,继续对外透出
export * from '@bot/agent';
export * from '@bot/config';
export * from '@bot/i18n';

let defaultApp: App | null = null;

/**
 * Cloudflare Workers 兼容入口:从 Workers 的 env 参数合并配置。
 * 其它平台(仅需 web 逻辑时)可直接用 createApp() 自定义 onRequest。
 */
export const Workers = {
    async fetch(request: Request, env: any): Promise<Response> {
        if (!defaultApp) {
            defaultApp = createApp({ onRequest: e => ENV.merge((e as Record<string, any>) ?? {}) });
        }
        return defaultApp.fetch(request, env);
    },
};
