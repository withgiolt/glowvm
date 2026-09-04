import glowvm
import gleam/pair
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all pair functions here
  let _ = pair.first(#(1, "a"))
  let _ = pair.second(#(1, "a"))
  let _ = pair.swap(#(1, "a"))
  let _ = pair.map_first(#(1, "a"), with: fn(x) { x + 1 })
  let _ = pair.map_second(#(1, "a"), with: fn(x) { x <> "!" })
  let _ = pair.new(1, "a")

  wisp.ok() |> wisp.string_body("OK")
}
