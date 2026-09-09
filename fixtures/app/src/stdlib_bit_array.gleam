import fixture_check
import glowvm
import gleam/bit_array
import gleam/order.{Lt}
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let ba = bit_array.from_string("hello")

  fixture_check.run([
    #("bit_array.bit_size(hello)", bit_array.bit_size(ba) == 40),
    #("bit_array.byte_size(hello)", bit_array.byte_size(ba) == 5),
    #(
      "bit_array.pad_to_bytes(hello)",
      bit_array.pad_to_bytes(ba) == bit_array.from_string("hello"),
    ),
    #(
      "bit_array.append(hello, world)",
      bit_array.append(to: ba, suffix: bit_array.from_string("world"))
        == bit_array.from_string("helloworld"),
    ),
    #(
      "bit_array.slice(hello, 0, 3)",
      bit_array.slice(from: ba, at: 0, take: 3)
        == Ok(bit_array.from_string("hel")),
    ),
    #("bit_array.is_utf8(hello)", bit_array.is_utf8(ba) == True),
    #("bit_array.to_string(hello)", bit_array.to_string(ba) == Ok("hello")),
    #(
      "bit_array.concat([hello, world])",
      bit_array.concat([ba, bit_array.from_string("world")])
        == bit_array.from_string("helloworld"),
    ),
    #(
      "bit_array.base64_encode(hello, True)",
      bit_array.base64_encode(ba, True) == "aGVsbG8=",
    ),
    #(
      "bit_array.base64_decode(aGVsbG8=)",
      bit_array.base64_decode("aGVsbG8=") == Ok(ba),
    ),
    #(
      "bit_array.base64_url_encode(hello, True)",
      bit_array.base64_url_encode(ba, True) == "aGVsbG8=",
    ),
    #(
      "bit_array.base64_url_decode(aGVsbG8=)",
      bit_array.base64_url_decode("aGVsbG8=") == Ok(ba),
    ),
    #(
      "bit_array.base16_encode(hello)",
      bit_array.base16_encode(ba) == "68656C6C6F",
    ),
    #(
      "bit_array.base16_decode(68656C6C6F)",
      bit_array.base16_decode("68656C6C6F") == Ok(ba),
    ),
    #(
      "bit_array.inspect(hello)",
      bit_array.inspect(ba) == "<<104, 101, 108, 108, 111>>",
    ),
    #(
      "bit_array.compare(hello, world)",
      bit_array.compare(ba, bit_array.from_string("world")) == Lt,
    ),
  ])
  // bit_array.starts_with is pure Gleam (`<<pref:bits-size(prefix_size), _>>`
  // with a runtime-variable segment size), which compiles to a dynamic-size
  // bitstring match. Confirmed by direct repro that this crashes the VM
  // outright — it's inlined match bytecode, not a function call, so there's
  // no seam an Erlang shim can intercept. Real AtomVM limitation, not a gap
  // this repo's shims can close; see README's bitstring-matching caveat.
  // let _ = bit_array.starts_with(ba, bit_array.from_string("he"))
}
