import fixture_check
import glowvm
import gleam/bit_array
import gleam/dynamic
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let dyn = dynamic.string("hello")

  fixture_check.run([
    #("dynamic.classify(string)", dynamic.classify(dyn) == "String"),
    #(
      "dynamic.classify(bool(True))",
      dynamic.classify(dynamic.bool(True)) == "Bool",
    ),
    #(
      "dynamic.classify(string(hello))",
      dynamic.classify(dynamic.string("hello")) == "String",
    ),
    #(
      "dynamic.classify(float(4.2))",
      dynamic.classify(dynamic.float(4.2)) == "Float",
    ),
    #(
      "dynamic.classify(int(42))",
      dynamic.classify(dynamic.int(42)) == "Int",
    ),
    #(
      // A BitArray built from valid UTF-8 bytes ("hello") is indistinguishable
      // from a String on Erlang — both are plain binaries — so
      // gleam_stdlib:classify_dynamic/1 classifies it as "String", not
      // "BitArray". Confirmed against the compiled host module, not assumed.
      "dynamic.classify(bit_array(hello))",
      dynamic.classify(dynamic.bit_array(bit_array.from_string("hello")))
        == "String",
    ),
    #(
      "dynamic.classify(list([dyn]))",
      dynamic.classify(dynamic.list([dyn])) == "List",
    ),
    #(
      "dynamic.classify(array([dyn]))",
      dynamic.classify(dynamic.array([dyn])) == "Array",
    ),
    #(
      "dynamic.classify(properties([#(dyn, dyn)]))",
      dynamic.classify(dynamic.properties([#(dyn, dyn)])) == "Dict",
    ),
    #("dynamic.classify(nil())", dynamic.classify(dynamic.nil()) == "Nil"),
    #(
      "dynamic.string(hello) == dynamic.string(hello)",
      dynamic.string("hello") == dyn,
    ),
  ])
}
