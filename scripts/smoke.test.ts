import { assertEquals, assertStringIncludes } from "@std/assert";

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

Deno.test("basic_get returns 200 with body", async () => {
  const r = await fetchFixture("basic_get", "/");
  assertEquals(r.status, 200);
  assertEquals(r.text, "hello from glowvm");
});

Deno.test("not_found returns 404", async () => {
  const r = await fetchFixture("not_found", "/anything");
  assertEquals(r.status, 404);
});

Deno.test("env_get returns secret", async () => {
  Deno.env.set("SECRET_KEY", "secret");

  const r = await fetchFixture("env_get", "/");
  assertEquals(r.status, 200);
  assertEquals(r.text, "secret");
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

Deno.test("echo_body round-trips binary bodies containing the frame marker", async () => {
  const marker = new TextEncoder().encode("\n__GLOWVM__");
  const body = new Uint8Array([0, 0xff, 131, ...marker, 0, 0, 0, 1, ...marker]);
  const r = await fetchFixture("echo_body", "/", { method: "POST", body });
  assertEquals(r.status, 200);
  assertEquals(r.headers.get("x-echo"), "1");
  assertEquals([...r.bytes], [...body]);
});

Deno.test("echo_body returns a body larger than the stdout buffer", async () => {
  const body = new Uint8Array(300_000).map((_, i) => i % 251);
  const r = await fetchFixture("echo_body", "/", { method: "POST", body });
  assertEquals(r.status, 200);
  assertEquals([...r.bytes], [...body]);
});

Deno.test("echo_body returns a large body intact", async () => {
  const body = new TextEncoder().encode(
    '<p>"quoted" & escaped \u00e9</p>\n'.repeat(2000),
  );
  const r = await fetchFixture("echo_body", "/", { method: "POST", body });
  assertEquals(r.status, 200);
  assertEquals(r.bytes.length, body.length);
  assertEquals(r.text, new TextDecoder().decode(body));
});

Deno.test("no_content returns 204 without a body", async () => {
  const r = await fetchFixture("no_content", "/");
  assertEquals(r.status, 204);
  assertEquals(r.bytes.length, 0);
});

Deno.test("file_body is not implemented", async () => {
  const r = await fetchFixture("file_body", "/");
  assertEquals(r.status, 501);
});

Deno.test("lustre html generations returns ok", async () => {
  const r = await fetchFixture("lustre_html", "/");
  assertStringIncludes(r.text, "<h1>hello from glowvm</h1>");
  assertEquals(r.status, 200);
});

Deno.test("stdlib", async (t) => {
  const modules = [
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

  for (const name of modules) {
    await t.step(name, async () => {
      const r = await fetchFixture(`stdlib_${name}`, "/");
      assertEquals(r.text, "OK");
      assertEquals(r.status, 200);
    });
  }
});
