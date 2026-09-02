import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleeunit
import gleeunit/should
import glowvm/internal/bridge
import wisp

pub fn main() -> Nil {
  gleeunit.main()
}

fn payload(method method: String, url url: String, body body: String) -> String {
  json.object([
    #("method", json.string(method)),
    #("url", json.string(url)),
    #("headers", json.object([#("host", json.string("example.com"))])),
    #("body", json.string(body)),
  ])
  |> json.to_string
}

pub fn ok_response_test() -> Nil {
  let out =
    bridge.handle(payload(method: "GET", url: "/hello", body: ""), fn(_req) {
      wisp.ok() |> wisp.string_body("hi there")
    })

  let assert Ok(resp) = json.parse(out, response_decoder())
  resp.status |> should.equal(200)
  resp.body |> should.equal("hi there")
  resp.encoding |> should.equal("utf8")
}

pub fn query_string_test() -> Nil {
  let out =
    bridge.handle(
      payload(method: "GET", url: "/search?q=gleam", body: ""),
      fn(req) {
        let assert [#("q", "gleam")] = wisp.get_query(req)
        wisp.ok() |> wisp.string_body("found")
      },
    )

  let assert Ok(resp) = json.parse(out, response_decoder())
  resp.status |> should.equal(200)
  resp.body |> should.equal("found")
}

pub fn unknown_method_is_bad_request_test() -> Nil {
  let out =
    bridge.handle(payload(method: "BAD METHOD", url: "/", body: ""), fn(_req) {
      wisp.ok()
    })

  let assert Ok(resp) = json.parse(out, response_decoder())
  resp.status |> should.equal(400)
}

pub fn invalid_utf8_bytes_are_base64_test() -> Nil {
  let out =
    bridge.handle(payload(method: "GET", url: "/", body: ""), fn(_req) {
      wisp.response(200)
      |> wisp.set_body(wisp.Bytes(bytes_tree.from_bit_array(<<0xFF>>)))
    })

  let assert Ok(resp) = json.parse(out, response_decoder())
  resp.status |> should.equal(200)
  resp.encoding |> should.equal("base64")
  resp.body |> should.equal("/w==")
}

pub fn file_body_is_not_implemented_test() -> Nil {
  let out =
    bridge.handle(payload(method: "GET", url: "/", body: ""), fn(_req) {
      wisp.response(200)
      |> wisp.set_body(wisp.File("/tmp/x", 0, option.None))
    })

  let assert Ok(resp) = json.parse(out, response_decoder())
  resp.status |> should.equal(501)
}

type DecodedResponse {
  DecodedResponse(status: Int, body: String, encoding: String)
}

fn response_decoder() -> decode.Decoder(DecodedResponse) {
  use status <- decode.field("status", decode.int)
  use body <- decode.field("body", decode.string)
  use encoding <- decode.field("encoding", decode.string)
  decode.success(DecodedResponse(status:, body:, encoding:))
}
