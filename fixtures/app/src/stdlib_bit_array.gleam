import glowvm
import gleam/bit_array
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all bit_array functions here
  let ba = bit_array.from_string("hello")

  let _ = bit_array.bit_size(ba)
  let _ = bit_array.byte_size(ba)
  let _ = bit_array.pad_to_bytes(ba)
  let _ = bit_array.append(to: ba, suffix: bit_array.from_string("world"))
  let _ = bit_array.slice(from: ba, at: 0, take: 3)
  let _ = bit_array.is_utf8(ba)
  let _ = bit_array.to_string(ba)
  let _ = bit_array.concat([ba, bit_array.from_string("world")])
  // let _ = bit_array.base64_encode(ba, True)
  let _ = bit_array.base64_decode("aGVsbG8=")
  // let _ = bit_array.base64_url_encode(ba, True)
  // let _ = bit_array.base64_url_decode("aGVsbG8=")
  let _ = bit_array.base16_encode(ba)
  let _ = bit_array.base16_decode("68656C6C6F")
  let _ = bit_array.inspect(ba)
  let _ = bit_array.compare(ba, bit_array.from_string("world"))
  // let _ = bit_array.starts_with(ba, bit_array.from_string("he"))

  wisp.ok() |> wisp.string_body("OK")
}
