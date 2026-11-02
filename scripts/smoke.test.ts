import { expect, test } from "bun:test";
import { plugin } from "bun";
import { readFileSync } from "node:fs";

// index.js imports ./glowvm.wasm as a WebAssembly.Module and ./app.avm as
// bytes, which is how workerd resolves them; Bun needs a plugin to do the same.
plugin({
  name: "glowvm-assets",
  setup(build) {
    build.onLoad({ filter: /glowvm\.wasm$/ }, (args) => ({
      exports: { default: new WebAssembly.Module(readFileSync(args.path)) },
      loader: "object",
    }));
    build.onLoad({ filter: /app\.avm$/ }, (args) => ({
      exports: { default: readFileSync(args.path) },
      loader: "object",
    }));
  },
});

const distDir = new URL("../fixtures/app/dist/", import.meta.url);

async function fetchFixture(
  name: string,
  path: string,
  init: RequestInit = {},
) {
  const indexUrl = new URL(`${name}/index.js`, distDir);
  const { default: worker } = await import(indexUrl.href);
  const request = new Request(`http://example.com${path}`, {
    method: "GET",
    headers: { host: "example.com" },
    ...init,
  });
  const response = await worker.fetch(request);
  const bytes = new Uint8Array(await response.arrayBuffer());
  return {
    status: response.status,
    headers: response.headers,
    bytes,
    text: new TextDecoder().decode(bytes),
  };
}

test("basic_get returns 200 with body", async () => {
  const r = await fetchFixture("basic_get", "/");
  expect(r.status).toEqual(200);
  expect(r.text).toEqual("hello from glowvm");
});

test("not_found returns 404", async () => {
  const r = await fetchFixture("not_found", "/anything");
  expect(r.status).toEqual(404);
});

test("env_get returns secret", async () => {
  process.env.SECRET_KEY = "secret";

  const r = await fetchFixture("env_get", "/");
  expect(r.status).toEqual(200);
  expect(r.text).toEqual("secret");
});

test("query_param reads the query string", async () => {
  const r = await fetchFixture("query_param", "/?msg=hi");
  expect(r.status).toEqual(200);
  expect(r.text).toEqual("hi");
});

test("bytes_body returns raw bytes", async () => {
  const r = await fetchFixture("bytes_body", "/");
  expect(r.status).toEqual(200);
  expect([...r.bytes]).toEqual([0xff]);
});

test("echo_body round-trips binary bodies containing the frame marker", async () => {
  const marker = new TextEncoder().encode("\n__GLOWVM__");
  const body = new Uint8Array([0, 0xff, 131, ...marker, 0, 0, 0, 1, ...marker]);
  const r = await fetchFixture("echo_body", "/", { method: "POST", body });
  expect(r.status).toEqual(200);
  expect(r.headers.get("x-echo")).toEqual("1");
  expect([...r.bytes]).toEqual([...body]);
});

test("echo_body returns a body larger than the stdout buffer", async () => {
  const body = new Uint8Array(300_000).map((_, i) => i % 251);
  const r = await fetchFixture("echo_body", "/", { method: "POST", body });
  expect(r.status).toEqual(200);
  expect([...r.bytes]).toEqual([...body]);
});

test("echo_body returns a large body intact", async () => {
  const body = new TextEncoder().encode(
    '<p>"quoted" & escaped \u00e9</p>\n'.repeat(2000),
  );
  const r = await fetchFixture("echo_body", "/", { method: "POST", body });
  expect(r.status).toEqual(200);
  expect(r.bytes.length).toEqual(body.length);
  expect(r.text).toEqual(new TextDecoder().decode(body));
});

test("no_content returns 204 without a body", async () => {
  const r = await fetchFixture("no_content", "/");
  expect(r.status).toEqual(204);
  expect(r.bytes.length).toEqual(0);
});

test("file_body is not implemented", async () => {
  const r = await fetchFixture("file_body", "/");
  expect(r.status).toEqual(501);
});

test("lustre html generations returns ok", async () => {
  const r = await fetchFixture("lustre_html", "/");
  expect(r.text).toContain("<h1>hello from glowvm</h1>");
  expect(r.status).toEqual(200);
});

const stdlibModules = [
    "string",
    "bool",
    "int",
    "float",
    "list",
    "option",
    "result",
    "order",
    "pair",
    "dict",
    "set",
    "bit_array",
    "string_tree",
    "uri",
    "function",
    "io",
    "bytes_tree",
    "dynamic",
  ];

for (const name of stdlibModules) {
  test(`stdlib ${name}`, async () => {
    const r = await fetchFixture(`stdlib_${name}`, "/");
    expect(r.text).toEqual("OK");
    expect(r.status).toEqual(200);
  });
}
