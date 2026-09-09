import fixture_check
import glowvm
import gleam/dict
import gleam/option
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let d = dict.from_list([#("a", 1), #("b", 2)])

  fixture_check.run([
    #("dict.size(d)", dict.size(d) == 2),
    #("dict.is_empty(d)", dict.is_empty(d) == False),
    #(
      "dict.to_list(d)",
      dict.to_list(d) == [#("a", 1), #("b", 2)],
    ),
    #("dict.has_key(d, a)", dict.has_key(d, "a") == True),
    #("dict.new()", dict.new() == dict.from_list([])),
    #("dict.get(d, a)", dict.get(d, "a") == Ok(1)),
    #(
      "dict.insert(d, c, 3)",
      dict.insert(into: d, for: "c", insert: 3)
        == dict.from_list([#("a", 1), #("b", 2), #("c", 3)]),
    ),
    #(
      "dict.map_values(d, *2)",
      dict.map_values(in: d, with: fn(_k, v) { v * 2 })
        == dict.from_list([#("a", 2), #("b", 4)]),
    ),
    #("dict.keys(d)", dict.keys(d) == ["a", "b"]),
    #("dict.values(d)", dict.values(d) == [1, 2]),
    #(
      "dict.filter(d, v>1)",
      dict.filter(in: d, keeping: fn(_k, v) { v > 1 })
        == dict.from_list([#("b", 2)]),
    ),
    #(
      "dict.take(d, [a])",
      dict.take(from: d, keeping: ["a"]) == dict.from_list([#("a", 1)]),
    ),
    #(
      "dict.merge(d, {c: 3})",
      dict.merge(into: d, from: dict.from_list([#("c", 3)]))
        == dict.from_list([#("a", 1), #("b", 2), #("c", 3)]),
    ),
    #(
      "dict.delete(d, a)",
      dict.delete(from: d, delete: "a") == dict.from_list([#("b", 2)]),
    ),
    #(
      "dict.drop(d, [a])",
      dict.drop(from: d, drop: ["a"]) == dict.from_list([#("b", 2)]),
    ),
    #(
      "dict.upsert(d, a, +1)",
      dict.upsert(in: d, update: "a", with: fn(v) {
        case v {
          option.Some(x) -> x + 1
          option.None -> 0
        }
      })
        == dict.from_list([#("a", 2), #("b", 2)]),
    ),
    #(
      "dict.fold(d, 0, +v)",
      dict.fold(over: d, from: 0, with: fn(acc, _k, v) { acc + v }) == 3,
    ),
    #(
      "dict.each(d)",
      dict.each(d, fn(_k, _v) { Nil }) == Nil,
    ),
    #(
      "dict.combine(d, {a: 10}, +)",
      dict.combine(d, dict.from_list([#("a", 10)]), fn(a, b) { a + b })
        == dict.from_list([#("a", 11), #("b", 2)]),
    ),
  ])
}
