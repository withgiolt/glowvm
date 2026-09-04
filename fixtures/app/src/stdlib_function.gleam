import glowvm
import gleam/function
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all function functions here
  let _ = function.identity(42)

  wisp.ok() |> wisp.string_body("OK")
}
