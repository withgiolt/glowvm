import glowvm
import gleam/dict
import gleam/option
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all dict functions here
  let d = dict.from_list([#("a", 1), #("b", 2)])

  let _ = dict.size(d)
  let _ = dict.is_empty(d)
  let _ = dict.to_list(d)
  let _ = dict.has_key(d, "a")
  let _ = dict.new()
  let _ = dict.get(d, "a")
  let _ = dict.insert(into: d, for: "c", insert: 3)
  let _ = dict.map_values(in: d, with: fn(_k, v) { v * 2 })
  let _ = dict.keys(d)
  let _ = dict.values(d)
  let _ = dict.filter(in: d, keeping: fn(_k, v) { v > 1 })
  // let _ = dict.take(from: d, keeping: ["a"])
  let _ = dict.merge(into: d, from: dict.from_list([#("c", 3)]))
  let _ = dict.delete(from: d, delete: "a")
  // let _ = dict.drop(from: d, drop: ["a"])
  let _ = dict.upsert(in: d, update: "a", with: fn(v) { case v { option.Some(x) -> x + 1 option.None -> 0 } })
  let _ = dict.fold(over: d, from: 0, with: fn(acc, _k, v) { acc + v })
  let _ = dict.each(d, fn(_k, _v) { Nil })
  let _ = dict.combine(d, dict.from_list([#("a", 10)]), fn(a, b) { a + b })

  wisp.ok() |> wisp.string_body("OK")
}
