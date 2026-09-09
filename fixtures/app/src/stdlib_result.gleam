import fixture_check
import glowvm
import gleam/result
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  fixture_check.run([
    #("result.is_ok(Ok(1))", result.is_ok(Ok(1)) == True),
    #("result.is_error(Error(e))", result.is_error(Error("e")) == True),
    #(
      "result.map(Ok(1), +1)",
      result.map(over: Ok(1), with: fn(x) { x + 1 }) == Ok(2),
    ),
    #(
      "result.map_error(Error(e), <>!)",
      result.map_error(over: Error("e"), with: fn(e) { e <> "!" })
        == Error("e!"),
    ),
    #("result.flatten(Ok(Ok(1)))", result.flatten(Ok(Ok(1))) == Ok(1)),
    #(
      "result.try(Ok(1), Ok(x+1))",
      result.try(Ok(1), fn(x) { Ok(x + 1) }) == Ok(2),
    ),
    #("result.unwrap(Ok(1), or: 0)", result.unwrap(Ok(1), or: 0) == 1),
    #(
      "result.lazy_unwrap(Ok(1), or: 0)",
      result.lazy_unwrap(Ok(1), or: fn() { 0 }) == 1,
    ),
    #(
      "result.unwrap_error(Error(e), or: default)",
      result.unwrap_error(Error("e"), or: "default") == "e",
    ),
    #("result.or(Ok(1), Ok(2))", result.or(Ok(1), Ok(2)) == Ok(1)),
    #(
      "result.lazy_or(Ok(1), Ok(2))",
      result.lazy_or(Ok(1), fn() { Ok(2) }) == Ok(1),
    ),
    #("result.all([Ok(1), Ok(2)])", result.all([Ok(1), Ok(2)]) == Ok([
      1, 2,
    ])),
    #(
      "result.partition([Ok(1), Error(e), Ok(2)])",
      result.partition([Ok(1), Error("e"), Ok(2)]) == #([2, 1], ["e"]),
    ),
    #("result.replace(Ok(1), new)", result.replace(Ok(1), "new") == Ok(
      "new",
    )),
    #(
      "result.replace_error(Error(e), new_error)",
      result.replace_error(Error("e"), "new_error") == Error("new_error"),
    ),
    #(
      "result.values([Ok(1), Error(e), Ok(2)])",
      result.values([Ok(1), Error("e"), Ok(2)]) == [1, 2],
    ),
    #(
      "result.try_recover(Error(e), Ok(1))",
      result.try_recover(Error("e"), with: fn(_) { Ok(1) }) == Ok(1),
    ),
  ])
}
