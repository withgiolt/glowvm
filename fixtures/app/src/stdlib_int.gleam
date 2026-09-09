import fixture_check
import glowvm
import gleam/int
import gleam/order.{Lt}
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let random_ten = int.random(10)

  fixture_check.run([
    #("int.absolute_value(-5)", int.absolute_value(-5) == 5),
    #("int.power(2, 3.0)", int.power(2, 3.0) == Ok(8.0)),
    #("int.square_root(9)", int.square_root(9) == Ok(3.0)),
    #("int.parse(42)", int.parse("42") == Ok(42)),
    #("int.base_parse(2a, 16)", int.base_parse("2a", 16) == Ok(42)),
    #("int.to_string(42)", int.to_string(42) == "42"),
    #(
      "int.to_base_string(42, 16)",
      int.to_base_string(42, 16) == Ok("2A"),
    ),
    #("int.to_base2(42)", int.to_base2(42) == "101010"),
    #("int.to_base8(42)", int.to_base8(42) == "52"),
    #("int.to_base16(42)", int.to_base16(42) == "2A"),
    #("int.to_base36(42)", int.to_base36(42) == "16"),
    #("int.to_float(42)", int.to_float(42) == 42.0),
    #("int.clamp(42, min: 0, max: 10)", int.clamp(42, min: 0, max: 10) == 10),
    #("int.compare(1, 2)", int.compare(1, 2) == Lt),
    #("int.min(1, 2)", int.min(1, 2) == 1),
    #("int.max(1, 2)", int.max(1, 2) == 2),
    #("int.is_even(4)", int.is_even(4) == True),
    #("int.is_odd(3)", int.is_odd(3) == True),
    #("int.negate(4)", int.negate(4) == -4),
    #("int.sum([1, 2, 3])", int.sum([1, 2, 3]) == 6),
    #("int.product([1, 2, 3])", int.product([1, 2, 3]) == 6),
    #(
      "int.random(10) in [0, 10)",
      random_ten >= 0 && random_ten < 10,
    ),
    #("int.divide(10, by: 3)", int.divide(10, by: 3) == Ok(3)),
    #("int.remainder(10, by: 3)", int.remainder(10, by: 3) == Ok(1)),
    #("int.modulo(10, by: 3)", int.modulo(10, by: 3) == Ok(1)),
    #("int.floor_divide(10, by: 3)", int.floor_divide(10, by: 3) == Ok(3)),
    #("int.add(1, 2)", int.add(1, 2) == 3),
    #("int.multiply(1, 2)", int.multiply(1, 2) == 2),
    #("int.subtract(1, 2)", int.subtract(1, 2) == -1),
    #("int.bitwise_and(6, 3)", int.bitwise_and(6, 3) == 2),
    #("int.bitwise_not(6)", int.bitwise_not(6) == -7),
    #("int.bitwise_or(6, 3)", int.bitwise_or(6, 3) == 7),
    #(
      "int.bitwise_exclusive_or(6, 3)",
      int.bitwise_exclusive_or(6, 3) == 5,
    ),
    #(
      "int.bitwise_shift_left(1, 2)",
      int.bitwise_shift_left(1, 2) == 4,
    ),
    #(
      "int.bitwise_shift_right(4, 1)",
      int.bitwise_shift_right(4, 1) == 2,
    ),
    #(
      "int.range(0, 5, [], prepend)",
      int.range(from: 0, to: 5, with: [], run: fn(acc, x) { [x, ..acc] })
        == [4, 3, 2, 1, 0],
    ),
  ])
}
