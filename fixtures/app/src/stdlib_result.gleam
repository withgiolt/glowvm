import glowvm
import gleam/result
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all result functions here
  let _ = result.is_ok(Ok(1))
  let _ = result.is_error(Error("e"))
  let _ = result.map(over: Ok(1), with: fn(x) { x + 1 })
  let _ = result.map_error(over: Error("e"), with: fn(e) { e <> "!" })
  let _ = result.flatten(Ok(Ok(1)))
  let _ = result.try(Ok(1), fn(x) { Ok(x + 1) })
  let _ = result.unwrap(Ok(1), or: 0)
  let _ = result.lazy_unwrap(Ok(1), or: fn() { 0 })
  let _ = result.unwrap_error(Error("e"), or: "default")
  let _ = result.or(Ok(1), Ok(2))
  let _ = result.lazy_or(Ok(1), fn() { Ok(2) })
  let _ = result.all([Ok(1), Ok(2)])
  let _ = result.partition([Ok(1), Error("e"), Ok(2)])
  let _ = result.replace(Ok(1), "new")
  let _ = result.replace_error(Error("e"), "new_error")
  let _ = result.values([Ok(1), Error("e"), Ok(2)])
  let _ = result.try_recover(Error("e"), with: fn(_) { Ok(1) })

  wisp.ok() |> wisp.string_body("OK")
}
