// Deno has no loader-hooks API (unlike Node's module.register), so the
// `import wasm from "./glowvm.wasm"` / `import avm from "./app.avm"` sugar
// in the real priv/index.js (workerd-only import semantics) can't be
// intercepted at runtime. Import maps CAN redirect a resolved file:// URL
// though, so for each fixture this drops a tiny loader .mjs next to the
// real asset and points a generated import map at it. The map has to live
// in dist/ (gitignored, absolute machine-local paths) rather than in
// deno.json itself — deno.json is tracked, and baking this machine's
// absolute paths into a committed file would break every other checkout.
// `deno test` then loads the actual index.js unmodified.
//
// Run before the tests: deno run -A scripts/gen_importmap.ts

const distDir = new URL("../fixtures/app/dist/", import.meta.url);

const imports: Record<string, string> = {
  "@std/assert": "jsr:@std/assert@^1.0.19",
};

for await (const entry of Deno.readDir(distDir)) {
  if (!entry.isDirectory) continue;
  const fixtureDir = new URL(`${entry.name}/`, distDir);

  const wasmUrl = new URL("glowvm.wasm", fixtureDir);
  const wasmLoaderUrl = new URL("glowvm.wasm.loader.mjs", fixtureDir);
  imports[wasmUrl.href] = wasmLoaderUrl.href;

  const avmUrl = new URL("app.avm", fixtureDir);
  const avmLoaderUrl = new URL("app.avm.loader.mjs", fixtureDir);
  imports[avmUrl.href] = avmLoaderUrl.href;
}

await Deno.writeTextFile(
  new URL("importmap.json", distDir),
  JSON.stringify({ imports }, null, 2),
);
