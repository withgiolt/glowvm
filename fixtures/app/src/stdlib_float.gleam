import fixture_check
import glowvm
import gleam/float
import gleam/order.{Lt}
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let random_value = float.random()
  let log_ok = case float.logarithm(4.2) {
    Ok(v) -> float.loosely_equals(v, 1.4350845252893227, tolerating: 0.0000001)
    Error(_) -> False
  }
  let exp_ok =
    float.loosely_equals(
      float.exponential(4.2),
      66.68633104092515,
      tolerating: 0.0000001,
    )

  fixture_check.run([
    #("float.parse(4.2)", float.parse("4.2") == Ok(4.2)),
    #("float.to_string(4.2)", float.to_string(4.2) == "4.2"),
    #(
      "float.clamp(4.2, min: 0.0, max: 10.0)",
      float.clamp(4.2, min: 0.0, max: 10.0) == 4.2,
    ),
    #("float.compare(1.0, 2.0)", float.compare(1.0, 2.0) == Lt),
    #(
      "float.loosely_compare(1.0, 1.01, 0.1)",
      float.loosely_compare(1.0, 1.01, tolerating: 0.1) == order.Eq,
    ),
    #(
      "float.loosely_equals(1.0, 1.01, 0.1)",
      float.loosely_equals(1.0, 1.01, tolerating: 0.1) == True,
    ),
    #("float.min(1.0, 2.0)", float.min(1.0, 2.0) == 1.0),
    #("float.max(1.0, 2.0)", float.max(1.0, 2.0) == 2.0),
    #("float.ceiling(4.2)", float.ceiling(4.2) == 5.0),
    #("float.floor(4.2)", float.floor(4.2) == 4.0),
    #("float.round(4.2)", float.round(4.2) == 4),
    #("float.truncate(4.2)", float.truncate(4.2) == 4),
    #("float.to_precision(4.2222, 2)", float.to_precision(4.2222, 2) == 4.22),
    #("float.absolute_value(-4.2)", float.absolute_value(-4.2) == 4.2),
    #("float.power(2.0, 3.0)", float.power(2.0, 3.0) == Ok(8.0)),
    #("float.square_root(9.0)", float.square_root(9.0) == Ok(3.0)),
    #("float.negate(4.2)", float.negate(4.2) == -4.2),
    #("float.sum([1.0, 2.0, 3.0])", float.sum([1.0, 2.0, 3.0]) == 6.0),
    #("float.product([1.0, 2.0, 3.0])", float.product([1.0, 2.0, 3.0]) == 6.0),
    #(
      "float.random() in [0.0, 1.0)",
      random_value >=. 0.0 && random_value <. 1.0,
    ),
    #("float.modulo(10.0, by: 3.0)", float.modulo(10.0, by: 3.0) == Ok(1.0)),
    #(
      "float.divide(10.0, by: 3.0)",
      float.divide(10.0, by: 3.0) == Ok(10.0 /. 3.0),
    ),
    #("float.add(1.0, 2.0)", float.add(1.0, 2.0) == 3.0),
    #("float.multiply(1.0, 2.0)", float.multiply(1.0, 2.0) == 2.0),
    #("float.subtract(1.0, 2.0)", float.subtract(1.0, 2.0) == -1.0),
    #("float.logarithm(4.2) ~= ln(4.2)", log_ok),
    #("float.exponential(4.2) ~= e^4.2", exp_ok),
  ])
}
