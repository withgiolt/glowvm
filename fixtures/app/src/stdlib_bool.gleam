import fixture_check
import glowvm
import gleam/bool
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  fixture_check.run([
    #("bool.and(True, False)", bool.and(True, False) == False),
    #("bool.or(True, False)", bool.or(True, False) == True),
    #("bool.negate(True)", bool.negate(True) == False),
    #("bool.nor(True, False)", bool.nor(True, False) == False),
    #("bool.nand(True, False)", bool.nand(True, False) == True),
    #("bool.exclusive_or(True, False)", bool.exclusive_or(True, False) == True),
    #(
      "bool.exclusive_nor(True, False)",
      bool.exclusive_nor(True, False) == False,
    ),
    #("bool.to_string(True)", bool.to_string(True) == "True"),
    #(
      "bool.guard(True, yes, no)",
      bool.guard(True, "yes", fn() { "no" }) == "yes",
    ),
    #(
      "bool.lazy_guard(True, yes, no)",
      bool.lazy_guard(True, fn() { "yes" }, fn() { "no" }) == "yes",
    ),
  ])
}
