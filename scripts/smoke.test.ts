// End-to-end smoke test: imports the REAL priv/index.js (via its packed
// copy in each fixture's dist/<name>/index.js) and calls its actual
// fetch(request) with a genuine Fetch API Request/Response — so what's
// under test is byte-identical to what would ship to a Worker, not a
// hand-copied reimplementation of the WASI shim.
//
// Each fixture under fixtures/smoke_app/src is a single small app testing
// one thing. Run in order:
//   cd fixtures/smoke_app && gleam run -m build_all
//   deno run -A scripts/gen_importmap.ts
//   deno test -A --import-map=fixtures/smoke_app/dist/importmap.json scripts/smoke.test.ts
import { assertEquals } from "@std/assert";

const distDir = new URL("../fixtures/smoke_app/dist/", import.meta.url);

async function fetchFixture(name: string, path: string) {
  const indexUrl = new URL(`${name}/index.js`, distDir);
  const { default: worker } = await import(indexUrl.href);
  const request = new Request(`http://example.com${path}`, {
    method: "GET",
    headers: { host: "example.com" },
  });
  const response = await worker.fetch(request);
  const bytes = new Uint8Array(await response.arrayBuffer());
  return {
    status: response.status,
    bytes,
    text: new TextDecoder().decode(bytes),
  };
}

Deno.test("basic_get returns 200 with body", async () => {
  const r = await fetchFixture("basic_get", "/");
  assertEquals(r.status, 200);
  assertEquals(r.text, "hello from glowvm");
});

Deno.test("not_found returns 404", async () => {
  const r = await fetchFixture("not_found", "/anything");
  assertEquals(r.status, 404);
});

Deno.test("query_param reads the query string", async () => {
  const r = await fetchFixture("query_param", "/?msg=hi");
  assertEquals(r.status, 200);
  assertEquals(r.text, "hi");
});

Deno.test("bytes_body returns raw bytes", async () => {
  const r = await fetchFixture("bytes_body", "/");
  assertEquals(r.status, 200);
  assertEquals([...r.bytes], [0xff]);
});

Deno.test("file_body is not implemented", async () => {
  const r = await fetchFixture("file_body", "/");
  assertEquals(r.status, 501);
});
