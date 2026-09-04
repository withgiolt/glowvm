import glowvm
import gleam/set
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all set functions here
  let s1 = set.from_list([1, 2, 3])
  let s2 = set.from_list([2, 3, 4])

  let _ = set.new()
  let _ = set.size(s1)
  let _ = set.is_empty(s1)
  let _ = set.insert(into: s1, this: 5)
  let _ = set.contains(in: s1, this: 2)
  let _ = set.delete(from: s1, this: 2)
  let _ = set.to_list(s1)
  let _ = set.fold(over: s1, from: 0, with: fn(acc, m) { acc + m })
  let _ = set.filter(in: s1, keeping: fn(m) { m > 1 })
  let _ = set.map(s1, with: fn(m) { m * 2 })
  let _ = set.drop(from: s1, drop: [1])
  // let _ = set.take(from: s1, keeping: [1, 2])
  let _ = set.union(of: s1, and: s2)
  // let _ = set.intersection(of: s1, and: s2)
  let _ = set.difference(from: s1, minus: s2)
  // let _ = set.is_subset(s1, of: s2)
  // let _ = set.is_disjoint(s1, from: s2)
  // let _ = set.symmetric_difference(of: s1, and: s2)
  let _ = set.each(s1, fn(_m) { Nil })

  wisp.ok() |> wisp.string_body("OK")
}
