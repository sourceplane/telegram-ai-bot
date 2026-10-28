import { createVitestConfig } from '../../tooling/vitest/shared.mjs';

export default createVitestConfig({
    root: import.meta.dirname,
    workspaceDeps: ['ai', 'config', 'i18n'],
});
