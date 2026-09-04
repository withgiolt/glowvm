import glowvm
import gleam/int
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all int functions here
  let _ = int.absolute_value(-5)
  let _ = int.power(2, 3.0)
  let _ = int.square_root(9)
  let _ = int.parse("42")
  let _ = int.base_parse("2a", 16)
  let _ = int.to_string(42)
  let _ = int.to_base_string(42, 16)
  let _ = int.to_base2(42)
  let _ = int.to_base8(42)
  let _ = int.to_base16(42)
  let _ = int.to_base36(42)
  let _ = int.to_float(42)
  let _ = int.clamp(42, min: 0, max: 10)
  let _ = int.compare(1, 2)
  let _ = int.min(1, 2)
  let _ = int.max(1, 2)
  let _ = int.is_even(4)
  let _ = int.is_odd(3)
  let _ = int.negate(4)
  let _ = int.sum([1, 2, 3])
  let _ = int.product([1, 2, 3])
  // let _ = int.random(10)
  let _ = int.divide(10, by: 3)
  let _ = int.remainder(10, by: 3)
  let _ = int.modulo(10, by: 3)
  let _ = int.floor_divide(10, by: 3)
  let _ = int.add(1, 2)
  let _ = int.multiply(1, 2)
  let _ = int.subtract(1, 2)
  let _ = int.bitwise_and(6, 3)
  let _ = int.bitwise_not(6)
  let _ = int.bitwise_or(6, 3)
  let _ = int.bitwise_exclusive_or(6, 3)
  let _ = int.bitwise_shift_left(1, 2)
  let _ = int.bitwise_shift_right(4, 1)
  let _ = int.range(from: 0, to: 5, with: [], run: fn(acc, x) { [x, ..acc] })

  wisp.ok() |> wisp.string_body("OK")
}
