import fixture_check
import glowvm
import gleam/set
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let s1 = set.from_list([1, 2, 3])
  let s2 = set.from_list([2, 3, 4])

  fixture_check.run([
    #("set.new()", set.new() == set.from_list([])),
    #("set.size(s1)", set.size(s1) == 3),
    #("set.is_empty(s1)", set.is_empty(s1) == False),
    #(
      "set.insert(s1, 5)",
      set.insert(into: s1, this: 5) == set.from_list([1, 2, 3, 5]),
    ),
    #("set.contains(s1, 2)", set.contains(in: s1, this: 2) == True),
    #(
      "set.delete(s1, 2)",
      set.delete(from: s1, this: 2) == set.from_list([1, 3]),
    ),
    #("set.to_list(s1)", set.to_list(s1) == [1, 2, 3]),
    #(
      "set.fold(s1, 0, +)",
      set.fold(over: s1, from: 0, with: fn(acc, m) { acc + m }) == 6,
    ),
    #(
      "set.filter(s1, >1)",
      set.filter(in: s1, keeping: fn(m) { m > 1 }) == set.from_list([2, 3]),
    ),
    #(
      "set.map(s1, *2)",
      set.map(s1, with: fn(m) { m * 2 }) == set.from_list([2, 4, 6]),
    ),
    #(
      "set.drop(s1, [1])",
      set.drop(from: s1, drop: [1]) == set.from_list([2, 3]),
    ),
    #(
      "set.take(s1, [1, 2])",
      set.take(from: s1, keeping: [1, 2]) == set.from_list([1, 2]),
    ),
    #(
      "set.union(s1, s2)",
      set.union(of: s1, and: s2) == set.from_list([1, 2, 3, 4]),
    ),
    #(
      "set.intersection(s1, s2)",
      set.intersection(of: s1, and: s2) == set.from_list([2, 3]),
    ),
    #(
      "set.difference(s1, s2)",
      set.difference(from: s1, minus: s2) == set.from_list([1]),
    ),
    #("set.is_subset(s1, s2)", set.is_subset(s1, of: s2) == False),
    #("set.is_disjoint(s1, s2)", set.is_disjoint(s1, from: s2) == False),
    #(
      "set.symmetric_difference(s1, s2)",
      set.symmetric_difference(of: s1, and: s2) == set.from_list([1, 4]),
    ),
    #("set.each(s1)", set.each(s1, fn(_m) { Nil }) == Nil),
  ])
}
