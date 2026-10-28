import { createVitestConfig } from '../../tooling/vitest/shared.mjs';

export default createVitestConfig({
    root: import.meta.dirname,
    workspaceDeps: ['i18n'],
});
