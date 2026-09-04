import glowvm
import gleam/bit_array
import gleam/bytes_tree
import gleam/string_tree
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all bytes_tree functions here
  let bits = bit_array.from_string("hello")
  let tree = bytes_tree.from_bit_array(bits)

  let _ = bytes_tree.new()
  let _ = bytes_tree.prepend(to: tree, prefix: bits)
  let _ = bytes_tree.append(to: tree, suffix: bits)
  let _ = bytes_tree.prepend_tree(to: tree, prefix: tree)
  let _ = bytes_tree.append_tree(to: tree, suffix: tree)
  let _ = bytes_tree.prepend_string(to: tree, prefix: "hi ")
  let _ = bytes_tree.append_string(to: tree, suffix: " bye")
  let _ = bytes_tree.concat([tree, tree])
  let _ = bytes_tree.concat_bit_arrays([bits, bits])
  let _ = bytes_tree.from_string("hello")
  let _ = bytes_tree.from_string_tree(string_tree.from_string("hello"))
  let _ = bytes_tree.to_bit_array(tree)
  let _ = bytes_tree.byte_size(tree)

  wisp.ok() |> wisp.string_body("OK")
}
