// The libraries' shared Vitest configuration — upstream's
// vitest.config.shared.ts, unchanged in substance: every test runs inside
// workerd (Miniflare), so the Workers runtime APIs a test touches are the
// ones the deployed Worker has, not Node's.
//
//   root           the package's root (pass import.meta.dirname)
//   hashAlias      resolve `#/*` to the package's `src/*`
//   workspaceDeps  sibling packages (names without the @bot/ scope) resolved
//                  to their sources rather than their built dist/
import * as path from "node:path";
import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

export function createVitestConfig(options) {
  const root = options.root;
  const alias = [];
  if (options.hashAlias) {
    alias.push({ find: /^#\/(.*)$/, replacement: `${path.resolve(root, "src")}/$1` });
  }
  for (const dep of options.workspaceDeps || []) {
    alias.push({
      find: `@bot/${dep}`,
      replacement: path.resolve(root, `../${dep}/src/index.ts`),
    });
  }
  return defineConfig({
    plugins: [
      cloudflareTest({
        miniflare: {
          compatibilityDate: "2026-08-04",
          compatibilityFlags: ["nodejs_compat"],
        },
      }),
    ],
    resolve: { alias },
    test: {
      globals: true,
      include: ["src/**/*.test.ts"],
    },
  });
}
