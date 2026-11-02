# glowvm

Run Gleam serverlessly via AtomVM compiled to WebAssembly

GlowVM compiles AtomVM to `wasm32-wasi`, with WASI bindings and a few shims
and NIFs for compatibility, so Gleam's Erlang target can run inside a
Cloudflare Worker (or any WASI-compliant host). Gleam modules are compiled
and packed into an AtomVM PackBeam (`.avm`) file, loaded by AtomVM at request
time.

[Docs](https://docs.giolt.com/glowvm/about) — a Giolt project.

**Status: experimental, not ready for production use.** GlowVM inherits
AtomVM's constraints — 64-bit signed integers only, no hot code swapping, no
distributed Erlang, no C-based NIFs, limited non-byte-aligned bitstring
matching, partial OTP stdlib coverage, and a stateless, request-scoped
execution model. Prefer pure-Gleam dependencies and test early on GlowVM
rather than assuming a successful build implies runtime correctness.

Known gaps beyond that:

- **`crypto`** — only `crypto:strong_rand_bytes/1` exists (a platform NIF);
  `otp_crypto.c` is excluded from the WASM build, so `gleam_crypto` and
  wisp's signed cookies/sessions (`crypto:hash/2`, `crypto:mac/4`) don't work.
- **Uncaught crashes report opaquely.** AtomVM's own error reporting needs
  `init`, but `init` is never called from Erlang bytecode, so packbeam's
  pruning always strips it — any unhandled exception in a handler surfaces as
  `Failed load module: init.beam` instead of the real reason. Wrap
  handler logic in `try`/`catch` if you need the actual error client-side.
- **`gleam/string`'s grapheme functions treat graphemes as codepoints**
  (`src/shims/string.erl`), so combining marks, emoji ZWJ sequences and Hangul
  jamo don't cluster correctly. Case mapping (`uppercase`/`lowercase`) covers
  ASCII, Latin-1, Latin Extended-A, Greek and Cyrillic only.

## Setup

Requires macOS or Linux.

| Tool                                                | Version | Used for                                                                                        |
| --------------------------------------------------- | ------- | ----------------------------------------------------------------------------------------------- |
| [cmake](https://cmake.org/)                         | >= 3.20 | building `native/`                                                                              |
| Erlang/OTP                                          | >= 28   | `erlc`, and Gleam's Erlang target                                                               |
| [Gleam](https://gleam.run/)                         | >= 1.18 | building this library                                                                           |
| [Binaryen](https://github.com/WebAssembly/binaryen) | any     | `wasm-opt` / `wasm-dis` / `wasm-as`, used to repack the WASM output into a form workerd accepts |
| [wasi-sdk](https://github.com/WebAssembly/wasi-sdk) | 34      | the WASI clang toolchain                                                                        |
| [just](https://ju.st)                               | any     | The runner                                                                                      |

On macOS, the first four are a `brew install cmake erlang gleam binaryen just`
away.

wasi-sdk has no Homebrew formula: download the release archive for your
platform from the [v34 release
page](https://github.com/WebAssembly/wasi-sdk/releases/tag/wasi-sdk-34) and
extract it to `~/.wasi-sdk`. `scripts/build-atomvm.sh` looks for it at
`~/.wasi-sdk`, `/opt/wasi-sdk`, `/usr/local/wasi-sdk`, and `./wasi-sdk` in
this repo, or at `$WASI_SDK_PATH` if set.

## Build

```sh
just build
```

Clones the `vendor/AtomVM` submodule on first run if it isn't present, builds
`native/` with `cmake`, repacks and optimizes the WASM with Binaryen, and
writes `priv/glowvm.wasm` plus the Erlang stdlib subset into `priv/stdlib/`.

```sh
gleam build      # compile this library on its own
```

## Building an app

glowvm is the runtime only. The [`giolt`](https://giolt.hexdocs.pm/) CLI compiles
your project, checks that your entry module exports `handle`, packs it into an
AtomVM PackBeam (`app.avm`) and copies the runtime files below into your output
directory. Your project does not depend on glowvm directly.

```gleam
pub fn handle(req: wisp.Request) -> wisp.Response {
  wisp.ok() |> wisp.string_body("hello from glowvm")
}
```

`giolt` generates a `start/0` that calls `glowvm.serve(fn(req) { your.handle(req) })`.
The handler has to be called through a lambda: passing `your.handle` by reference
makes the packer drop your modules.

## Runtime contract

What `giolt` relies on, and what a change here has to keep stable:

| Path | Purpose |
| --- | --- |
| `glowvm.serve/1` | Guest-side bridge: reads one request (Erlang external term format) from stdin, calls the handler, writes the response to stdout. One VM run per request |
| `priv/glowvm.wasm` | AtomVM compiled to `wasm32-wasi` |
| `priv/index.js`, `priv/index.min.js` | Worker entry that loads `./glowvm.wasm` and `./app.avm` and answers `fetch` |
| `priv/stdlib/*.beam` | Curated Erlang stdlib subset, packed into every app |

The protocol between the host JavaScript and the guest bridge is versioned with
this package: a change to it is a minor version bump while glowvm is `0.x`, and
`giolt` declares the range of glowvm versions it supports.

## Issues

Found a bug or have a request? File it in [withgiolt/issues](https://github.com/withgiolt/issues), the central issue tracker for all Giolt projects.

## Attribution

This project is inspired by [Jaketdaniels/elixir-workers](https://github.com/Jaketdaniels/elixir-workers).
The code has been heavily modified to remove the 2 pass system, use latest AtomVM with OTP >=28,
add support for environment variables, Gleam support and more.
