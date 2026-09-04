import glowvm
import gleam/float
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all float functions here
  let _ = float.parse("4.2")
  // let _ = float.to_string(4.2)
  let _ = float.clamp(4.2, min: 0.0, max: 10.0)
  let _ = float.compare(1.0, 2.0)
  let _ = float.loosely_compare(1.0, 1.01, tolerating: 0.1)
  let _ = float.loosely_equals(1.0, 1.01, tolerating: 0.1)
  let _ = float.min(1.0, 2.0)
  let _ = float.max(1.0, 2.0)
  let _ = float.ceiling(4.2)
  let _ = float.floor(4.2)
  let _ = float.round(4.2)
  let _ = float.truncate(4.2)
  let _ = float.to_precision(4.2222, 2)
  let _ = float.absolute_value(-4.2)
  let _ = float.power(2.0, 3.0)
  let _ = float.square_root(9.0)
  let _ = float.negate(4.2)
  let _ = float.sum([1.0, 2.0, 3.0])
  let _ = float.product([1.0, 2.0, 3.0])
  // let _ = float.random()
  let _ = float.modulo(10.0, by: 3.0)
  let _ = float.divide(10.0, by: 3.0)
  let _ = float.add(1.0, 2.0)
  let _ = float.multiply(1.0, 2.0)
  let _ = float.subtract(1.0, 2.0)
  let _ = float.logarithm(4.2)
  let _ = float.exponential(4.2)

  wisp.ok() |> wisp.string_body("OK")
}
