import fixture_check
import glowvm
import gleam/function
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  fixture_check.run([#("function.identity(42)", function.identity(42) == 42)])
}
