import fixture_check
import glowvm
import gleam/pair
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  fixture_check.run([
    #("pair.first(#(1, a))", pair.first(#(1, "a")) == 1),
    #("pair.second(#(1, a))", pair.second(#(1, "a")) == "a"),
    #("pair.swap(#(1, a))", pair.swap(#(1, "a")) == #("a", 1)),
    #(
      "pair.map_first(#(1, a), +1)",
      pair.map_first(#(1, "a"), with: fn(x) { x + 1 }) == #(2, "a"),
    ),
    #(
      "pair.map_second(#(1, a), <>!)",
      pair.map_second(#(1, "a"), with: fn(x) { x <> "!" }) == #(1, "a!"),
    ),
    #("pair.new(1, a)", pair.new(1, "a") == #(1, "a")),
  ])
}
