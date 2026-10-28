import * as path from 'node:path'
import { createVitestConfig } from '../../tooling/vitest/shared.mjs'

// The port's own tests, in workerd as the libraries' are. They drive the
// Worker's entry (apps/bot/src) over the libraries' sources; the admin page
// is the HTML string @bot/web builds (turbo builds it first: `^build`).
const libs = ['agent', 'ai', 'config', 'core', 'i18n', 'plugins', 'telegram', 'types']
const config = createVitestConfig({ root: import.meta.dirname, workspaceDeps: [] })
config.resolve = {
  alias: [
    { find: /^@\/(.*)$/, replacement: `${path.resolve(import.meta.dirname, '../../apps/bot/src')}/$1` },
    { find: '@bot/web', replacement: path.resolve(import.meta.dirname, '../../packages/web/dist/index.js') },
    ...libs.map((lib) => ({
      find: `@bot/${lib}`,
      replacement: path.resolve(import.meta.dirname, `../../packages/${lib}/src/index.ts`),
    })),
  ],
}
export default config
