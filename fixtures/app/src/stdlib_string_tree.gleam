import glowvm
import gleam/string_tree
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all string_tree functions here
  let tree = string_tree.from_string("hello")

  let _ = string_tree.new()
  let _ = string_tree.prepend(to: tree, prefix: "say ")
  let _ = string_tree.append(to: tree, suffix: " world")
  let _ = string_tree.prepend_tree(to: tree, prefix: string_tree.from_string("say "))
  let _ = string_tree.append_tree(to: tree, suffix: string_tree.from_string(" world"))
  let _ = string_tree.from_strings(["hello", " ", "world"])
  let _ = string_tree.concat([tree, string_tree.from_string(" world")])
  let _ = string_tree.to_string(tree)
  let _ = string_tree.byte_size(tree)
  let _ = string_tree.join([tree, string_tree.from_string("world")], with: ", ")
  // let _ = string_tree.lowercase(tree)
  // let _ = string_tree.uppercase(tree)
  // let _ = string_tree.reverse(tree)
  let _ = string_tree.split(tree, on: "l")
  // let _ = string_tree.replace(in: tree, each: "l", with: "L")
  // let _ = string_tree.is_equal(tree, string_tree.from_string("hello"))
  // let _ = string_tree.is_empty(tree)

  wisp.ok() |> wisp.string_body("OK")
}
