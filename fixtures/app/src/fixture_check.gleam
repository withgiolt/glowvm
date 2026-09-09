import gleam/list
import gleam/string
import wisp

/// Shared by every stdlib_*.gleam fixture: run a list of (label, passed)
/// checks and turn the result into a response. 200 "OK" if everything
/// passed; 500 naming every failed label otherwise, so a real assertion
/// failure is visible in the response body instead of masquerading as a
/// passing smoke test.
pub fn run(checks: List(#(String, Bool))) -> wisp.Response {
  let failures =
    list.filter_map(checks, fn(c) {
      case c.1 {
        True -> Error(Nil)
        False -> Ok(c.0)
      }
    })

  case failures {
    [] -> wisp.ok() |> wisp.string_body("OK")
    _ ->
      wisp.internal_server_error()
      |> wisp.string_body("FAIL: " <> string.join(failures, ", "))
  }
}
