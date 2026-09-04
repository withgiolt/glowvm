import glowvm
import gleam/io
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all io functions here
  io.print("hello")
  io.print_error("hello")
  io.println("hello")
  io.println_error("hello")

  wisp.ok() |> wisp.string_body("OK")
}
