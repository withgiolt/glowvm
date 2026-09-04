import glowvm
import gleam/bool
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all bool functions here
  let _ = bool.and(True, False)
  let _ = bool.or(True, False)
  let _ = bool.negate(True)
  let _ = bool.nor(True, False)
  let _ = bool.nand(True, False)
  let _ = bool.exclusive_or(True, False)
  let _ = bool.exclusive_nor(True, False)
  let _ = bool.to_string(True)
  let _ = bool.guard(True, "yes", fn() { "no" })
  let _ = bool.lazy_guard(True, fn() { "yes" }, fn() { "no" })

  wisp.ok() |> wisp.string_body("OK")
}
