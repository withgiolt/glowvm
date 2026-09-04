import glowvm
import gleam/bit_array
import gleam/dynamic
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all dynamic functions here
  let dyn = dynamic.string("hello")

  let _ = dynamic.classify(dyn)
  let _ = dynamic.bool(True)
  let _ = dynamic.string("hello")
  let _ = dynamic.float(4.2)
  let _ = dynamic.int(42)
  let _ = dynamic.bit_array(bit_array.from_string("hello"))
  let _ = dynamic.list([dyn])
  let _ = dynamic.array([dyn])
  let _ = dynamic.properties([#(dyn, dyn)])
  let _ = dynamic.nil()

  wisp.ok() |> wisp.string_body("OK")
}
