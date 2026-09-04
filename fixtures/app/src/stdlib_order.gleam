import glowvm
import gleam/order.{Eq, Gt, Lt}
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all order functions here
  let _ = order.negate(Lt)
  let _ = order.to_int(Gt)
  let _ = order.compare(Lt, Gt)
  let _ = order.reverse(order.compare)
  let _ = order.break_tie(in: Eq, with: Gt)
  let _ = order.lazy_break_tie(in: Eq, with: fn() { Gt })

  wisp.ok() |> wisp.string_body("OK")
}
