import { createVitestConfig } from '../../tooling/vitest/shared.mjs';

export default createVitestConfig({
    root: import.meta.dirname,
    hashAlias: true,
    workspaceDeps: ['ai', 'agent', 'config', 'telegram', 'plugins', 'i18n', 'web'],
});
