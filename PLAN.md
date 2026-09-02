# Plan: `handler(wisp.Request) -> wisp.Response` as the glowvm user API

Goal: a glowvm user writes `app.gleam` with a wisp handler. `glowvm/build`
packs it into `app.avm`; `index.js` + `glowvm.wasm` run it on Cloudflare
Workers. Everything between stdin JSON and the handler is glowvm's job.

## Target user code

```gleam
// app.gleam
import glowvm
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(req: wisp.Request) -> wisp.Response {
  case wisp.path_segments(req) {
    [] -> wisp.ok() |> wisp.string_body("hello from AtomVM")
    _ -> wisp.not_found()
  }
}
```

One line of boilerplate (`start/0` calling `glowvm.serve`), no codegen. The
handler's type is checked by the compiler because `serve` takes it as an
argument — so no package-interface introspection is needed to validate the
handler shape.

Rejected alternative: build-time codegen of a `start/0` wrapper module so the
user writes only `handler/1`. It saves one line and costs a generated module,
a name convention, and a second failure mode. Revisit only if the one line
turns out to confuse people.

**Decision: wisp, not the hand-rolled `Conn`.** wisp brings routing helpers,
cookies, form/JSON body handling, static-ish responses, and an ecosystem
(`wisp/simulate` for user tests). It makes `internal/conn.gleam`,
`internal/body.gleam`, `internal/html.gleam` and `internal/url.gleam`
redundant — those get deleted.

## Data flow

```
CF fetch → index.js builds payload JSON → stdin
  → AtomVM runs app:start/0 → glowvm.serve
      → host_io:read_stdin (NIF)
      → decode payload
      → wisp.Request  (canned connection over body bits)
      → user handler
      → wisp.Response → response JSON
      → host_io:write_stdout (NIF)
  → index.js parses stdout → new Response(...)
```

Payload in (index.js → wasm) — worker-only, no CF `env` bindings or
`ExecutionContext`. `fetch(request)` is all glowvm touches:

```json
{ "method": "GET", "url": "/a/b?x=1", "headers": {"host": "..."},
  "body": "" }
```

Response out (wasm → index.js), sentinel-framed (see Phase 2):

```json
{ "status": 200, "headers": [["content-type","text/html"]],
  "body": "...", "encoding": "utf8" | "base64" }
```

Headers go out as a **pair list**, not an object: wisp emits repeated
`set-cookie` headers and a JSON object silently drops all but one. `new
Headers([[k,v],...])` accepts pairs, so the JS side gets simpler, not harder.

---

## Phase 0 — runtime gaps (blocking; wisp crashes without this)

Verified against this tree, not guessed. Only fixed what's *proven* necessary
— no more speculative shims; add the rest reactively when the smoke check
(Phase 5) actually hits them, per explicit direction not to pre-build them.

| Gap | Why it bites | Fix |
| --- | --- | --- |
| `crypto:strong_rand_bytes/1` | `native/CMakeLists.txt:52` excludes `otp_crypto.c`, and it's absent from AtomVM's generated `nifs_hash.h` (unlike `os:getenv/1`, which — see below — is already a real NIF there). `wisp.create_canned_connection` → `internal.make_connection` → `random_slug` calls it on **every request**, so this is not optional. | **Done.** NIF added in `native/src/platform_nifs.c` (`nif_crypto_strong_rand_bytes`, chunked over `getentropy()` from `<sys/random.h>`, WASI's `random_get` import backs it — `priv/index.js` already implements that). Registered as `"crypto:strong_rand_bytes/1"` next to the existing `host_io:*` entries. Rebuilt clean with `just build`. |

Ruled out, do not "fix":

- **`os:getenv/1`** — turned out already correct. AtomVM's `nifs.c` has a real
  `os_getenv_nif` calling libc `getenv()`, present in this build's
  `native/include/nifs_hash.h`, resolved *before* any Erlang `os` module
  bytecode or platform-NIF fallback is even consulted. `priv/index.js`'s WASI
  shim already reports zero env vars (`environ_sizes_get` returns 0/0), so
  `getenv()` already safely returns `false` for everything. A `src/os.erl`
  shim was tried and **reproducibly crashes host Erlang boot** —
  `os:internal_init_cmd_shell/0` is called by kernel startup, and shipping a
  same-named module in this project's `src/` (compiled into the same `ebin`
  used for both `gleam test`/`gleam run` on host *and* the AtomVM pack)
  replaces the whole module, kernel included. Confirmed by reproduction, not
  guessed. Do not re-add this file.
- **`logging` → `logger:*`** — wisp only touches it on error paths
  (`log_error`, `log_request`). Not pre-built speculatively; add only if a
  smoke check actually hits it.

Two more gaps turned up by *actually running* the Phase 5 smoke check
end-to-end through the real `glowvm.wasm` + `app.avm` (not guessed ahead of
time — this is the reactive fixing the instruction asked for):

| Gap | Why it bites | Fix |
| --- | --- | --- |
| `string:lowercase/1` | Not in AtomVM's estdlib at all. `glowvm.gleam` used it to lowercase header names. | Header names are always ASCII tokens per the HTTP spec — a full Unicode-aware lowercase was never actually needed. Replaced with a local ASCII-only `ascii_lowercase` (binary_to_list/list_to_binary, same trick already used elsewhere in this codebase). |
| `base64:encode/2`, `binary:encode_hex/1` | `bit_array.base64_encode`/`base16_encode` in gleam_stdlib both call OTP 26+ signatures (`base64:encode/2` with an options map; `binary:encode_hex/1`) that AtomVM's NIF table doesn't have — confirmed absent from `native/include/nifs_hash.h`. AtomVM *does* have the plain `base64:encode/1`. | Added a local `@external(erlang, "base64", "encode")` in `glowvm.gleam` calling that 1-arity form directly, bypassing gleam_stdlib's broken wrapper. Used for both the response's base64-encoded-body path and (transiently, see below) the wisp secret. |
| `os:type/0` | Not in AtomVM's NIF table. `directories.tmp_dir()` (via `wisp.create_canned_connection` → `internal.make_connection`, called on every request) needs it to pick a candidate temp-dir list. | **Done**, but see below — this NIF is no longer on the hot path after the `tmp_dir()` bypass, kept anyway since it's cheap, general, and correct (matches real OTP `os:type/0` semantics: `{unix, linux}`). Registered in `native/src/platform_nifs.c` next to `crypto:strong_rand_bytes/1`. |
| `file:read_file_info/2` | Also via `directories.tmp_dir()`, checking whether `/tmp` etc. exist. `posix_nifs.c` (which would provide this) is excluded from the WASI build (`native/CMakeLists.txt:58`) — correctly, since there's no real filesystem to report on. | **Not fixed with a NIF** — see below, the whole call chain was bypassed instead. |
| `base64:encode/2` (again) | `internal.random_slug()` (used to build a unique temp-dir name) calls `bit_array.base64_url_encode`, hitting the same broken 2-arity wrapper. | Same bypass as `file:read_file_info` below — no random uniqueness needed for a directory nothing ever writes to. |
| `uri_string:dissect_query/1` / `parse/1` | Not in AtomVM's estdlib. `wisp.get_query/1` needs it — confirmed by the smoke check failing on `GET /echo?msg=hi` with "module uri_string cannot be resolved". | Re-added the `src/uri_string.erl` shim (written and validated earlier, pulled, now restored because it's proven necessary rather than guessed). Same risk profile as before: shadows the real host `uri_string` for this project's tests and any downstream consumer's, but isn't touched at kernel boot so it doesn't crash anything the way `os.erl` did. |

**`directories.tmp_dir()` was the wrong thing to keep patching.** Chasing
`os:type/0` then `file:read_file_info/2` then `random_slug`'s base64 call
one NIF at a time was solving a problem that doesn't matter: the temp
directory it computes exists only to stream multipart file uploads to disk,
and a Cloudflare Worker has no disk. Stopped adding native fixes for it and
instead bypassed `wisp.create_canned_connection` entirely — `glowvm.gleam`
now builds the `wisp.Connection` directly via `wisp/internal` (a plain,
unmarked-internal module wisp happens to also use itself) with a fixed
`temporary_directory` literal, and its own tiny `canned_reader` (an exact
copy of wisp's private one — `Reader`/`Read` are public types, the reader
function itself just isn't exported). Zero native gaps left in that path.

Also fixed: the sentinel from Phase 2 only bounded the *start* of the
response payload. AtomVM's own `globalcontext_run` prints `Return value:
<term>` to stdout after `start/0` returns (confirmed in
`vendor/AtomVM/src/libAtomVM/globalcontext.c:787`), trailing after our JSON
— so `parseOutput` in `priv/index.js` now combines the sentinel (bounds the
start, defeats a stray print in user code) with the original balanced-brace
scan (bounds the end, defeats AtomVM's own trailer).

Check for this phase, now passing against the real `glowvm.wasm` + `app.avm`
(see Phase 5 for the harness): `GET /` → 200, `GET /missing` → 404,
`GET /echo?msg=hi` → 200 with the query decoded via `wisp.get_query`.

## Phase 1 — `glowvm.serve`

Replace the stub in `src/glowvm/entry.gleam` (rename to `src/glowvm.gleam` so
the user's import is just `import glowvm`).

```gleam
pub fn serve(handler: fn(wisp.Request) -> wisp.Response) -> Nil {
  wasi.read_stdin() |> handle(handler) |> wasi.write_stdout
}

// pure, and therefore the thing the test drives
fn handle(payload: String, handler: fn(wisp.Request) -> wisp.Response) -> String
```

Request construction (all public API, no `wisp/internal` reach-through —
that module matches Gleam's default `internal_modules` pattern and cannot be
imported from here):

- decode payload with `gleam/json` + `gleam/dynamic/decode`
- `http.parse_method` for the method; unknown → 400 without invoking the handler
- split `url` on `?` into `path` / `query`
- headers: object → `List(#(String, String))`, keys lowercased (gleam_http
  requires lowercase keys)
- body: `String` → `BitArray` → `wisp.create_canned_connection(bits, secret)`
- `request.Request(method:, headers:, body: connection, scheme: Https,
  host: <from host header>, port: None, path:, query:)`

`secret`: 64 random bytes per request — no `env` is passed in at all (worker
part only, per user). Random-per-request means signed cookies never verify
across requests, which is the safe failure — never ship a hardcoded default
key. (Signed cookies are unsupported anyway; see Open Questions.)

Response serialisation:

- `Text(s)` → body `s`, `encoding: "utf8"`
- `Bytes(tree)` → `bytes_tree.to_bit_array` → `bit_array.to_string`; on
  `Error` fall back to base64 with `encoding: "base64"`
- `File(_, _, _)` → 501 + logged message. There is no filesystem on a Worker.
  Static assets belong in CF Assets or KV, not in this path.
- handler crash → let it abort; `index.js` already turns a non-zero exit into
  a 502. Do not add a catch-all that hides real errors.

## Phase 2 — `priv/index.js` diet

Currently 565 lines, most of it inherited from ElixirWorkers and dead. This
is the worker part only — no CF bindings, no `env`, no `ExecutionContext`:

- **Delete** `fulfillNeeds`, `executeEffects`, the `_needs`/`_state`/`_effects`
  two-pass protocol, `extractEnvVars`, the `env`/`cf` fields on the payload,
  `FAVICON_SVG` and its route (an Elixir drop logo served from a Gleam
  runtime), and the `workerEnv`/`ctx` parameters on `fetch` — `export default
  { async fetch(request) { ... } }` takes only the request. ~280 lines gone.
  Re-add bindings only when a Gleam API actually needs them.
- **Keep** `mkWasi`, `runWasm`, the 1 MB body cap.
- **Change** response handling: `headers` is now a pair array →
  `new Response(body, { status, headers: result.headers })` works unchanged;
  honour `encoding: "base64"` by decoding to bytes before constructing the
  Response.
- **Framing:** `parseOutput` scans for the first `{` in stdout, so a stray
  `io:format` in user code corrupts the response. Have `write_stdout` prefix
  the payload with a sentinel (`\n__GLOWVM__`) and have JS take the text after
  the **last** sentinel. Three lines each side, removes a whole class of
  "works until you add a debug print" bugs.

## Phase 3 — `src/glowvm/build.gleam` (done)

- `start/0` check kept — a missing `start/0` otherwise surfaces as "No main
  module found" at request time (`native/src/main.c:126`), a terrible
  first-run experience. Error messages reworded to point at `glowvm.serve`
  and explain the "call glowvm.serve *from* start/0" direction, since that's
  the mistake someone's actually likely to make.
- The handler *signature* check is free now (the compiler does it via
  `serve`'s parameter type), so the package-interface code wasn't extended.
- **`build()` now takes a `module_name` label**, not just `output_dir`. A
  project with one app names its entrypoint module after the project (as
  before); a project hosting several — like `fixtures/smoke_app` below —
  passes each module in turn. Threaded through `validate_entrypoint` (looks
  up that module in the package-interface, not `proj.name`) and
  `bundle_beam_files`/`packbeam_create` (packs that module's beam as the
  AtomVM start module).
- **`glowvm_priv_dir` fallback added**: hex dependencies stage at
  `build/packages/<name>/priv/` (confirmed against `atomvm_packbeam`'s
  hex-staged source tree); a `path`-dependency (glowvm's own fixtures, or
  developing against an unpublished checkout) only ever produces
  `build/dev/erlang/<name>/priv/` — no `build/packages/<name>` at all. Falls
  back to the latter so path-dependency consumers don't need a manual
  `build/packages/glowvm` symlink.
- **Size:** measured, not guessed — a real packed `app.avm` (wisp +
  everything it pulls in: mist, glisten, gramps, hpack, directories, envoy,
  etc.) comes to ~400 KB, plus `glowvm.wasm` at ~575 KB. Both well under any
  practical Workers bundle limit. `list_beam_files` still globs every
  `.beam` under `build/dev/erlang` (no per-package pruning), but a
  blocklist isn't earning its complexity at this size — skipped. Revisit
  only if a future dependency graph pushes `app.avm` toward ~1 MB.

## Phase 4 — deletions and `glowvm/internal` reorg (done)

Deleted, superseded by wisp:

- `src/glowvm/internal/conn.gleam` — wisp's `Request`/`Response` replace it
- `src/glowvm/internal/body.gleam` — `wisp.require_form` / `require_json`
- `src/glowvm/internal/html.gleam` — `houdini` via wisp
- `src/glowvm/internal/url.gleam` — `gleam/uri` + `wisp.path_segments`

Also moved, not just deleted: the payload<->wisp translation logic that
first landed directly in `src/glowvm.gleam` (as private `fn`s) moved to
`src/glowvm/internal/bridge.gleam` instead. Private `fn`s are invisible
outside their own file, which was already enough to hide them from
consumers — but `glowvm/internal` is the project's *real* privacy
mechanism (declared in `gleam.toml`'s `internal_modules`, so the compiler
warns any external importer, the same warning this plan's own `gleam/crypto`
dependency triggered). Using it means `src/glowvm.gleam` is now purely the
public surface — one function (`serve`), one docstring — while
`bridge.gleam` holds the JSON decode/encode, the `wisp.Connection` bypass,
and the `ascii_lowercase`/`base64_encode` helpers discovered in Phase 5.
`test/glowvm_test.gleam` imports `glowvm/internal/bridge` directly (same
package as the library, so no warning) rather than needing an `@internal`
escape hatch on an exported `glowvm.handle`.

Kept: `internal/wasi.gleam` and `src/host_io.erl` (the NIF bridge).

## Phase 5 — checks (done)

1. `test/glowvm_test.gleam` (gleeunit, one file): drives the pure
   `bridge.handle(payload, handler)` — 200 with body and headers, query
   string reaching `wisp.get_query`, unknown method → 400, `Bytes` with
   invalid UTF-8 → base64, `File` → 501. Runs on host Erlang, where
   `host_io.erl`'s fallback path isn't even touched because `handle` is pure.
2. `fixtures/smoke_app/` + `scripts/smoke.mjs`: a real end-to-end check
   through the actual packed `glowvm.wasm` + `app.avm` + `index.js`,
   exercising exactly what gleeunit can't (AtomVM's native NIF table, its
   estdlib subset, the stdout framing, and — critically — the real worker
   entrypoint). One small fixture module per concern under
   `fixtures/smoke_app/src/` (`basic_get`, `not_found`, `query_param`,
   `bytes_body`, `file_body`) rather than one handler doing everything —
   `gleam run -m build_all` packs each via its own `build.build(module_name:
   ..)` call into `dist/<name>/`, and `scripts/smoke.mjs` fires one real
   Fetch API `Request` at each, asserting its specific expectation. This is
   what actually found and drove the fixes in the reactive-gaps table
   above — nothing there was guessed ahead of time.

   The runner imports the *actual* `dist/<name>/index.js` — not a
   hand-copied reimplementation of its WASI shim — and calls its real
   exported `fetch(request)`. Node has no native support for workerd's
   `import wasm from "./glowvm.wasm"` / `import avm from "./app.avm"`
   sugar, so `scripts/wasm-avm-hooks.mjs` is a small `node:module` loader
   hook (`register()`) that resolves those two extensions the way workerd
   does: `.wasm` → a compiled `WebAssembly.Module` (`.avm` → raw bytes),
   returned via synthetic ESM source text that reads its own file back
   through `import.meta.url` (the loader hook runs in an isolated
   thread/realm and can't hand a live object across that boundary
   directly). An earlier version of this script duplicated `index.js`'s
   `mkWasi`/`runWasm` logic by hand instead — working, but a second copy
   that could silently drift from the real file. Importing the real file
   removes that risk entirely.

## Order of work (as it actually went)

Phase 0's `crypto` NIF first (proven necessary before anything could even be
tried), then 1 → 2 → 5. Phase 5's smoke check is what surfaced every
Phase-0-reactive gap (`string:lowercase`, `base64:encode/2`,
`directories.tmp_dir()`'s whole chain, `uri_string`) and the stdout framing
bug — in that sense 5 drove 0, not the other way around, despite the section
ordering above. Then 3 (size, build() parameterization) and 4 (deletions +
the `glowvm/internal` reorg) last, once the design had stopped moving.

## Open questions

- **Env access / KV / D1 bindings.** Explicitly out of scope: this build is
  the worker part only, no CF `env` or `ExecutionContext` reaches glowvm.
  Revisit as a separate design pass if/when bindings are wanted.
- **Signed cookies** need `crypto:mac(hmac, sha256, ...)`, which is a bigger
  lift than `strong_rand_bytes` (a real SHA-256, or unexcluding `otp_crypto.c`
  and its mbedtls dependency). Until then `wisp.set_signed_cookie` aborts.
  Document it as unsupported rather than half-implementing it.
