import fixture_check
import glowvm
import gleam/order.{Eq, Gt, Lt}
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let reversed = order.reverse(order.compare)

  fixture_check.run([
    #("order.negate(Lt)", order.negate(Lt) == Gt),
    #("order.to_int(Gt)", order.to_int(Gt) == 1),
    #("order.compare(Lt, Gt)", order.compare(Lt, Gt) == Lt),
    #("order.reverse(compare)(Lt, Gt)", reversed(Lt, Gt) == Gt),
    #("order.break_tie(Eq, Gt)", order.break_tie(in: Eq, with: Gt) == Gt),
    #(
      "order.lazy_break_tie(Eq, Gt)",
      order.lazy_break_tie(in: Eq, with: fn() { Gt }) == Gt,
    ),
  ])
}
