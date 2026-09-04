import glowvm
import gleam/option.{None, Some}
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all option functions here
  let _ = option.all([Some(1), Some(2)])
  let _ = option.is_some(Some(1))
  let _ = option.is_none(None)
  let _ = option.to_result(Some(1), "error")
  let _ = option.from_result(Ok(1))
  let _ = option.unwrap(Some(1), or: 0)
  let _ = option.lazy_unwrap(Some(1), or: fn() { 0 })
  let _ = option.map(over: Some(1), with: fn(x) { x + 1 })
  let _ = option.flatten(Some(Some(1)))
  let _ = option.then(Some(1), apply: fn(x) { Some(x + 1) })
  let _ = option.or(Some(1), Some(2))
  let _ = option.lazy_or(Some(1), fn() { Some(2) })
  let _ = option.values([Some(1), None, Some(2)])

  wisp.ok() |> wisp.string_body("OK")
}
