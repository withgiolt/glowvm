import gleam/bytes_tree
import gleam/io
import glowvm
import wisp

/// Echoes the request body back after printing the response frame marker to
/// stdout, so neither a stray print nor a body containing the marker can be
/// mistaken for the real response frame.
pub fn start() {
  io.print("\n__GLOWVM__")
  glowvm.serve(handle_request)
}

fn handle_request(req: wisp.Request) -> wisp.Response {
  case wisp.read_body_bits(req) {
    Ok(body) ->
      wisp.response(200)
      |> wisp.set_header("x-echo", "1")
      |> wisp.set_body(wisp.Bytes(bytes_tree.from_bit_array(body)))
    Error(Nil) -> wisp.bad_request("unreadable body")
  }
}
