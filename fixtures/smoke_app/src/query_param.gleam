import glowvm
import wisp

/// Exercises wisp.get_query -> gleam/uri -> AtomVM's uri_string shim.
pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(req: wisp.Request) -> wisp.Response {
  case wisp.get_query(req) {
    [#("msg", msg), ..] -> wisp.ok() |> wisp.string_body(msg)
    _ -> wisp.ok() |> wisp.string_body("no msg")
  }
}
