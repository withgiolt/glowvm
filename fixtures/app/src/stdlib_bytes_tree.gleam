import fixture_check
import glowvm
import gleam/bit_array
import gleam/bytes_tree
import gleam/string_tree
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn expect(s: String) -> BitArray {
  bit_array.from_string(s)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let bits = bit_array.from_string("hello")
  let tree = bytes_tree.from_bit_array(bits)

  fixture_check.run([
    #(
      "bytes_tree.new()",
      bytes_tree.to_bit_array(bytes_tree.new()) == expect(""),
    ),
    #(
      "bytes_tree.prepend(tree, hello)",
      bytes_tree.to_bit_array(bytes_tree.prepend(to: tree, prefix: bits))
        == expect("hellohello"),
    ),
    #(
      "bytes_tree.append(tree, hello)",
      bytes_tree.to_bit_array(bytes_tree.append(to: tree, suffix: bits))
        == expect("hellohello"),
    ),
    #(
      "bytes_tree.prepend_tree(tree, tree)",
      bytes_tree.to_bit_array(bytes_tree.prepend_tree(
        to: tree,
        prefix: tree,
      ))
        == expect("hellohello"),
    ),
    #(
      "bytes_tree.append_tree(tree, tree)",
      bytes_tree.to_bit_array(bytes_tree.append_tree(to: tree, suffix: tree))
        == expect("hellohello"),
    ),
    #(
      "bytes_tree.prepend_string(tree, hi )",
      bytes_tree.to_bit_array(bytes_tree.prepend_string(
        to: tree,
        prefix: "hi ",
      ))
        == expect("hi hello"),
    ),
    #(
      "bytes_tree.append_string(tree,  bye)",
      bytes_tree.to_bit_array(bytes_tree.append_string(
        to: tree,
        suffix: " bye",
      ))
        == expect("hello bye"),
    ),
    #(
      "bytes_tree.concat([tree, tree])",
      bytes_tree.to_bit_array(bytes_tree.concat([tree, tree]))
        == expect("hellohello"),
    ),
    #(
      "bytes_tree.concat_bit_arrays([hello, hello])",
      bytes_tree.to_bit_array(bytes_tree.concat_bit_arrays([bits, bits]))
        == expect("hellohello"),
    ),
    #(
      "bytes_tree.from_string(hello)",
      bytes_tree.to_bit_array(bytes_tree.from_string("hello")) == expect(
        "hello",
      ),
    ),
    #(
      "bytes_tree.from_string_tree(hello)",
      bytes_tree.to_bit_array(bytes_tree.from_string_tree(
        string_tree.from_string("hello"),
      ))
        == expect("hello"),
    ),
    #("bytes_tree.to_bit_array(tree)", bytes_tree.to_bit_array(tree) == expect(
      "hello",
    )),
    #("bytes_tree.byte_size(tree)", bytes_tree.byte_size(tree) == 5),
  ])
}
