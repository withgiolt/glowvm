# glowvm

`glowvm` is retired and gets no further releases. Its replacement is
afterglow.

glowvm runs AtomVM in WebAssembly and interprets an app's BEAM bytecode at
request time. afterglow compiles that bytecode ahead of time to WebAssembly and
links it with a Rust runtime. It lives in
[github.com/withgiolt/afterglow](https://github.com/withgiolt/afterglow), and
the plan is in
[withgiolt/afterglow#1](https://github.com/withgiolt/afterglow/issues/1).

The `giolt` CLI builds Erlang-target apps with glowvm 0.3 until it switches to
afterglow.
