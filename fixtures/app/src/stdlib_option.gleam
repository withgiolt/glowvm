import fixture_check
import glowvm
import gleam/option.{None, Some}
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  fixture_check.run([
    #("option.all([Some(1), Some(2)])", option.all([Some(1), Some(2)]) == Some(
      [1, 2],
    )),
    #("option.is_some(Some(1))", option.is_some(Some(1)) == True),
    #("option.is_none(None)", option.is_none(None) == True),
    #(
      "option.to_result(Some(1), error)",
      option.to_result(Some(1), "error") == Ok(1),
    ),
    #("option.from_result(Ok(1))", option.from_result(Ok(1)) == Some(1)),
    #("option.unwrap(Some(1), or: 0)", option.unwrap(Some(1), or: 0) == 1),
    #(
      "option.lazy_unwrap(Some(1), or: 0)",
      option.lazy_unwrap(Some(1), or: fn() { 0 }) == 1,
    ),
    #(
      "option.map(Some(1), +1)",
      option.map(over: Some(1), with: fn(x) { x + 1 }) == Some(2),
    ),
    #("option.flatten(Some(Some(1)))", option.flatten(Some(Some(1))) == Some(
      1,
    )),
    #(
      "option.then(Some(1), Some(x+1))",
      option.then(Some(1), apply: fn(x) { Some(x + 1) }) == Some(2),
    ),
    #("option.or(Some(1), Some(2))", option.or(Some(1), Some(2)) == Some(1)),
    #(
      "option.lazy_or(Some(1), Some(2))",
      option.lazy_or(Some(1), fn() { Some(2) }) == Some(1),
    ),
    #(
      "option.values([Some(1), None, Some(2)])",
      option.values([Some(1), None, Some(2)]) == [1, 2],
    ),
  ])
}
