// End-to-end smoke test: imports the REAL priv/index.js (via its packed
// copy in each fixture's dist/<name>/index.js) and calls its actual
// fetch(request) with a genuine Fetch API Request/Response — so what's
// under test is byte-identical to what would ship to a Worker, not a
// hand-copied reimplementation of the WASI shim. wasm-avm-hooks.mjs teaches
// Node how to resolve the `import wasm from "./glowvm.wasm"` / `import avm
// from "./app.avm"` sugar that only workerd understands natively.
//
// Each fixture under fixtures/smoke_app/src is a single small app testing
// one thing — run `cd fixtures/smoke_app && gleam run -m build_all` first to
// pack each into its own dist/<name>/{app.avm,glowvm.wasm,index.js}.
//
// Usage:
//   cd fixtures/smoke_app && gleam run -m build_all
//   node scripts/smoke.mjs             # runs every fixture below
//   node scripts/smoke.mjs bytes_body  # or just one, by fixture name
import fs from "node:fs";
import { register } from "node:module";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

register("./wasm-avm-hooks.mjs", import.meta.url);

const fixturesDir = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "../fixtures/smoke_app/dist",
);

// One fixture module per check — see fixtures/smoke_app/src/*.gleam.
const fixtures = [
  {
    name: "basic_get",
    path: "/",
    assertFn: (r) => {
      if (r.status !== 200) throw new Error(`expected 200, got ${r.status}`);
      if (r.text !== "hello from glowvm") throw new Error(`unexpected body: ${r.text}`);
    },
  },
  {
    name: "not_found",
    path: "/anything",
    assertFn: (r) => {
      if (r.status !== 404) throw new Error(`expected 404, got ${r.status}`);
    },
  },
  {
    name: "query_param",
    path: "/?msg=hi",
    assertFn: (r) => {
      if (r.status !== 200) throw new Error(`expected 200, got ${r.status}`);
      if (r.text !== "hi") throw new Error(`unexpected body: ${r.text}`);
    },
  },
  {
    name: "bytes_body",
    path: "/",
    assertFn: (r) => {
      if (r.status !== 200) throw new Error(`expected 200, got ${r.status}`);
      if (r.bytes.length !== 1 || r.bytes[0] !== 0xff) {
        throw new Error(`expected [0xff], got ${JSON.stringify([...r.bytes])}`);
      }
    },
  },
  {
    name: "file_body",
    path: "/",
    assertFn: (r) => {
      if (r.status !== 501) throw new Error(`expected 501, got ${r.status}`);
    },
  },
];

const only = process.argv[2];
const targets = fixtures
  .filter((f) => !only || f.name === only)
  .map((f) => ({ ...f, dir: path.join(fixturesDir, f.name) }));

if (targets.length === 0) {
  console.error(`no fixture named "${only}" (known: ${fixtures.map((f) => f.name).join(", ")})`);
  process.exit(1);
}

for (const t of targets) {
  const indexPath = path.join(t.dir, "index.js");
  if (!fs.existsSync(indexPath)) {
    console.error(
      `no build found at ${t.dir}\nrun: cd fixtures/smoke_app && gleam run -m build_all`,
    );
    process.exit(1);
  }

  const { default: worker } = await import(pathToFileURL(indexPath).href);
  const request = new Request(`http://example.com${t.path}`, {
    method: "GET",
    headers: { host: "example.com" },
  });
  const response = await worker.fetch(request);
  const bytes = new Uint8Array(await response.arrayBuffer());

  t.assertFn({
    status: response.status,
    bytes,
    text: new TextDecoder().decode(bytes),
    headers: response.headers,
  });
  console.log(`ok - ${t.name}`);
}

console.log("\nall checks passed");
