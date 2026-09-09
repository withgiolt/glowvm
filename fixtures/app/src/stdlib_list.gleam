import fixture_check
import glowvm
import gleam/dict
import gleam/int
import gleam/list
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let shuffled = list.shuffle([1, 2, 3])
  let sorted_shuffled = list.sort(shuffled, by: int.compare)
  let sampled = list.sample(from: [1, 2, 3], up_to: 2)

  fixture_check.run([
    #("list.length([1, 2, 3])", list.length([1, 2, 3]) == 3),
    #(
      "list.count([1, 2, 3], where: >1)",
      list.count([1, 2, 3], where: fn(x) { x > 1 }) == 2,
    ),
    #("list.reverse([1, 2, 3])", list.reverse([1, 2, 3]) == [3, 2, 1]),
    #("list.is_empty([1, 2, 3])", list.is_empty([1, 2, 3]) == False),
    #(
      "list.contains([1, 2, 3], any: 2)",
      list.contains([1, 2, 3], any: 2) == True,
    ),
    #("list.first([1, 2, 3])", list.first([1, 2, 3]) == Ok(1)),
    #("list.rest([1, 2, 3])", list.rest([1, 2, 3]) == Ok([2, 3])),
    #(
      "list.group([1, 2, 3], by: %2)",
      list.group([1, 2, 3], by: fn(x) { x % 2 })
        == dict.from_list([#(0, [2]), #(1, [3, 1])]),
    ),
    #(
      "list.filter([1, 2, 3], keeping: >1)",
      list.filter([1, 2, 3], keeping: fn(x) { x > 1 }) == [2, 3],
    ),
    #(
      "list.filter_map([1, 2, 3], Ok(*2))",
      list.filter_map([1, 2, 3], with: fn(x) { Ok(x * 2) }) == [2, 4, 6],
    ),
    #(
      "list.map([1, 2, 3], *2)",
      list.map([1, 2, 3], with: fn(x) { x * 2 }) == [2, 4, 6],
    ),
    #(
      "list.map2([1, 2], [a, b])",
      list.map2([1, 2], ["a", "b"], with: fn(i, x) { #(i, x) }) == [
        #(1, "a"), #(2, "b"),
      ],
    ),
    #(
      "list.map_fold([1, 2, 3], 0, +)",
      list.map_fold(over: [1, 2, 3], from: 0, with: fn(acc, i) {
        #(acc + i, i * 2)
      })
        == #(6, [2, 4, 6]),
    ),
    #(
      "list.index_map([1, 2, 3])",
      list.index_map([1, 2, 3], with: fn(x, i) { #(x, i) }) == [
        #(1, 0), #(2, 1), #(3, 2),
      ],
    ),
    #(
      "list.try_map([1, 2, 3], Ok(*2))",
      list.try_map(over: [1, 2, 3], with: fn(x) { Ok(x * 2) })
        == Ok([2, 4, 6]),
    ),
    #(
      "list.drop([1, 2, 3], up_to: 1)",
      list.drop(from: [1, 2, 3], up_to: 1) == [2, 3],
    ),
    #(
      "list.take([1, 2, 3], up_to: 1)",
      list.take(from: [1, 2, 3], up_to: 1) == [1],
    ),
    #("list.new()", list.new() == []),
    #("list.wrap(1)", list.wrap(1) == [1]),
    #("list.append([1, 2], [3, 4])", list.append([1, 2], [3, 4]) == [
      1, 2, 3, 4,
    ]),
    #(
      "list.prepend([2, 3], this: 1)",
      list.prepend(to: [2, 3], this: 1) == [1, 2, 3],
    ),
    #(
      "list.flatten([[1, 2], [3, 4]])",
      list.flatten([[1, 2], [3, 4]]) == [1, 2, 3, 4],
    ),
    #(
      "list.flat_map([1, 2], [x, x])",
      list.flat_map([1, 2], with: fn(x) { [x, x] }) == [1, 1, 2, 2],
    ),
    #(
      "list.fold([1, 2, 3], 0, +)",
      list.fold(over: [1, 2, 3], from: 0, with: fn(acc, x) { acc + x }) == 6,
    ),
    #(
      "list.fold_right([1, 2, 3], 0, +)",
      list.fold_right(over: [1, 2, 3], from: 0, with: fn(acc, x) {
        acc + x
      })
        == 6,
    ),
    #(
      "list.index_fold([1, 2, 3], 0, +x+i)",
      list.index_fold(over: [1, 2, 3], from: 0, with: fn(acc, x, i) {
        acc + x + i
      })
        == 9,
    ),
    #(
      "list.try_fold([1, 2, 3], 0, Ok(+))",
      list.try_fold(over: [1, 2, 3], from: 0, with: fn(acc, x) {
        Ok(acc + x)
      })
        == Ok(6),
    ),
    #(
      "list.fold_until([1, 2, 3], 0, Continue(+))",
      list.fold_until(over: [1, 2, 3], from: 0, with: fn(acc, x) {
        list.Continue(acc + x)
      })
        == 6,
    ),
    #(
      "list.find([1, 2, 3], one_that: >1)",
      list.find(in: [1, 2, 3], one_that: fn(x) { x > 1 }) == Ok(2),
    ),
    #(
      "list.find_map([1, 2, 3], Ok(x))",
      list.find_map(in: [1, 2, 3], with: fn(x) { Ok(x) }) == Ok(1),
    ),
    #(
      "list.all([1, 2, 3], satisfying: >0)",
      list.all(in: [1, 2, 3], satisfying: fn(x) { x > 0 }) == True,
    ),
    #(
      "list.any([1, 2, 3], satisfying: >2)",
      list.any(in: [1, 2, 3], satisfying: fn(x) { x > 2 }) == True,
    ),
    #("list.zip([1, 2], [a, b])", list.zip([1, 2], ["a", "b"]) == [
      #(1, "a"), #(2, "b"),
    ]),
    #(
      "list.strict_zip([1, 2], [a, b])",
      list.strict_zip([1, 2], ["a", "b"]) == Ok([#(1, "a"), #(2, "b")]),
    ),
    #(
      "list.unzip([#(1, a), #(2, b)])",
      list.unzip([#(1, "a"), #(2, "b")]) == #([1, 2], ["a", "b"]),
    ),
    #(
      "list.intersperse([1, 2, 3], with: 0)",
      list.intersperse([1, 2, 3], with: 0) == [1, 0, 2, 0, 3],
    ),
    #("list.unique([1, 1, 2])", list.unique([1, 1, 2]) == [1, 2]),
    #(
      "list.sort([3, 1, 2], by: int.compare)",
      list.sort([3, 1, 2], by: int.compare) == [1, 2, 3],
    ),
    #(
      "list.repeat(a, times: 3)",
      list.repeat(item: "a", times: 3) == ["a", "a", "a"],
    ),
    #(
      "list.split([1, 2, 3], at: 1)",
      list.split(list: [1, 2, 3], at: 1) == #([1], [2, 3]),
    ),
    #(
      "list.split_while([1, 2, 3], <2)",
      list.split_while(list: [1, 2, 3], satisfying: fn(x) { x < 2 })
        == #([1], [2, 3]),
    ),
    #(
      "list.key_find([#(a, 1)], a)",
      list.key_find(in: [#("a", 1)], find: "a") == Ok(1),
    ),
    #(
      "list.key_filter([#(a, 1)], a)",
      list.key_filter(in: [#("a", 1)], find: "a") == [1],
    ),
    #(
      "list.key_pop([#(a, 1)], a)",
      list.key_pop([#("a", 1)], "a") == Ok(#(1, [])),
    ),
    #(
      "list.key_set([#(a, 1)], b, 2)",
      list.key_set([#("a", 1)], "b", 2) == [#("a", 1), #("b", 2)],
    ),
    #("list.each([1, 2, 3])", list.each([1, 2, 3], fn(_) { Nil }) == Nil),
    #(
      "list.try_each([1, 2, 3], Ok(Nil))",
      list.try_each(over: [1, 2, 3], with: fn(_) { Ok(Nil) }) == Ok(Nil),
    ),
    #(
      "list.partition([1, 2, 3], >1)",
      list.partition([1, 2, 3], with: fn(x) { x > 1 }) == #([2, 3], [1]),
    ),
    #(
      "list.permutations([1, 2])",
      list.permutations([1, 2]) == [[1, 2], [2, 1]],
    ),
    #(
      "list.window([1, 2, 3], by: 2)",
      list.window([1, 2, 3], by: 2) == [[1, 2], [2, 3]],
    ),
    #(
      "list.window_by_2([1, 2, 3])",
      list.window_by_2([1, 2, 3]) == [#(1, 2), #(2, 3)],
    ),
    #(
      "list.drop_while([1, 2, 3], <2)",
      list.drop_while(in: [1, 2, 3], satisfying: fn(x) { x < 2 }) == [2, 3],
    ),
    #(
      "list.take_while([1, 2, 3], <2)",
      list.take_while(in: [1, 2, 3], satisfying: fn(x) { x < 2 }) == [1],
    ),
    #(
      "list.chunk([1, 1, 2], by: identity)",
      list.chunk([1, 1, 2], by: fn(x) { x }) == [[1, 1], [2]],
    ),
    #(
      "list.sized_chunk([1, 2, 3, 4], into: 2)",
      list.sized_chunk([1, 2, 3, 4], into: 2) == [[1, 2], [3, 4]],
    ),
    #(
      "list.reduce([1, 2, 3], +)",
      list.reduce(over: [1, 2, 3], with: fn(a, b) { a + b }) == Ok(6),
    ),
    #(
      "list.scan([1, 2, 3], 0, +)",
      list.scan(over: [1, 2, 3], from: 0, with: fn(acc, x) { acc + x })
        == [1, 3, 6],
    ),
    #("list.last([1, 2, 3])", list.last([1, 2, 3]) == Ok(3)),
    #(
      "list.combinations([1, 2, 3], by: 2)",
      list.combinations([1, 2, 3], by: 2) == [[1, 2], [1, 3], [2, 3]],
    ),
    #(
      "list.combination_pairs([1, 2, 3])",
      list.combination_pairs([1, 2, 3]) == [#(1, 2), #(1, 3), #(2, 3)],
    ),
    #(
      "list.interleave([[1, 2], [3, 4]])",
      list.interleave([[1, 2], [3, 4]]) == [1, 3, 2, 4],
    ),
    #(
      "list.transpose([[1, 2], [3, 4]])",
      list.transpose([[1, 2], [3, 4]]) == [[1, 3], [2, 4]],
    ),
    #(
      "list.shuffle([1, 2, 3]) is a permutation",
      sorted_shuffled == [1, 2, 3] && list.length(shuffled) == 3,
    ),
    #(
      "list.max([1, 2, 3], with: int.compare)",
      list.max(over: [1, 2, 3], with: int.compare) == Ok(3),
    ),
    #(
      "list.sample([1, 2, 3], up_to: 2)",
      list.length(sampled) == 2
        && list.all(sampled, fn(x) { list.contains([1, 2, 3], any: x) }),
    ),
  ])
}
