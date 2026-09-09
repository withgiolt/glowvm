import fixture_check
import glowvm
import gleam/list
import gleam/string_tree
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let tree = string_tree.from_string("hello")

  let split_strings =
    string_tree.split(tree, on: "l") |> list.map(string_tree.to_string)

  fixture_check.run([
    #("string_tree.new()", string_tree.to_string(string_tree.new()) == ""),
    #(
      "string_tree.prepend(tree, say )",
      string_tree.to_string(string_tree.prepend(to: tree, prefix: "say "))
        == "say hello",
    ),
    #(
      "string_tree.append(tree,  world)",
      string_tree.to_string(string_tree.append(to: tree, suffix: " world"))
        == "hello world",
    ),
    #(
      "string_tree.prepend_tree(tree, say )",
      string_tree.to_string(string_tree.prepend_tree(
        to: tree,
        prefix: string_tree.from_string("say "),
      ))
        == "say hello",
    ),
    #(
      "string_tree.append_tree(tree,  world)",
      string_tree.to_string(string_tree.append_tree(
        to: tree,
        suffix: string_tree.from_string(" world"),
      ))
        == "hello world",
    ),
    #(
      "string_tree.from_strings([hello,  , world])",
      string_tree.to_string(string_tree.from_strings(["hello", " ", "world"]))
        == "hello world",
    ),
    #(
      "string_tree.concat([tree,  world])",
      string_tree.to_string(
        string_tree.concat([tree, string_tree.from_string(" world")]),
      )
        == "hello world",
    ),
    #("string_tree.to_string(tree)", string_tree.to_string(tree) == "hello"),
    #("string_tree.byte_size(tree)", string_tree.byte_size(tree) == 5),
    #(
      "string_tree.join([tree, world], , )",
      string_tree.to_string(string_tree.join(
        [tree, string_tree.from_string("world")],
        with: ", ",
      ))
        == "hello, world",
    ),
    #(
      "string_tree.lowercase(tree)",
      string_tree.to_string(string_tree.lowercase(tree)) == "hello",
    ),
    #(
      "string_tree.uppercase(tree)",
      string_tree.to_string(string_tree.uppercase(tree)) == "HELLO",
    ),
    #(
      "string_tree.reverse(tree)",
      string_tree.to_string(string_tree.reverse(tree)) == "olleh",
    ),
    #(
      "string_tree.split(tree, on: l)",
      split_strings == ["he", "", "o"],
    ),
    #(
      "string_tree.replace(tree, l, L)",
      string_tree.to_string(string_tree.replace(
        in: tree,
        each: "l",
        with: "L",
      ))
        == "heLLo",
    ),
    #(
      "string_tree.is_equal(tree, hello)",
      string_tree.is_equal(tree, string_tree.from_string("hello")) == True,
    ),
    #("string_tree.is_empty(tree)", string_tree.is_empty(tree) == False),
  ])
}
