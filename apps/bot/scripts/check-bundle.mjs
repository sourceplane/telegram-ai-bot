#!/usr/bin/env node
// Upstream's bundle guard (packages/apps/workers/scripts/check-bundle.ts):
// the Worker is pure ESM, loaded by workerd, which has no `require`. A
// CommonJS dependency bundled into it makes the bundler inject a dynamic
// require shim — the build still succeeds, and the Worker crashes on start
// ("Dynamic require of … is not supported"). This fails the build instead.
//
//   node scripts/check-bundle.mjs [dist/index.js]
import * as fs from "node:fs";

const MARKER = "in an environment that doesn't expose the `require` function";
const bundle = process.argv[2] ?? "dist/index.js";
const source = fs.readFileSync(bundle, "utf8");
if (source.includes(MARKER)) {
  console.error(
    `[check-bundle] ${bundle} contains a CommonJS \`require\` shim: a bundled CJS dependency ` +
      "is not loadable by workerd and would crash the Worker at startup. Remove or replace it.",
  );
  process.exit(1);
}
console.log(`[check-bundle] ${bundle} is dependency-free ESM.`);
