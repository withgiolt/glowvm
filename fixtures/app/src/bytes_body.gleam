import gleam/bytes_tree
import glowvm
import wisp

/// Non-UTF8 bytes in the response body must reach the client unchanged.
pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  wisp.response(200)
  |> wisp.set_body(wisp.Bytes(bytes_tree.from_bit_array(<<0xFF>>)))
}
