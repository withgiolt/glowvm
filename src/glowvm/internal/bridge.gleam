/// Translates between the stdin/stdout JSON protocol (index.js <-> AtomVM)
/// and wisp's Request/Response types. Not meant for glowvm users — the
/// public surface is `glowvm.serve`.
import gleam/bit_array
import gleam/bytes_tree
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import glowvm/internal/wasi
import wisp
import wisp/internal

pub fn serve(handler: fn(wisp.Request) -> wisp.Response) -> Nil {
  wasi.read_stdin()
  |> handle(handler)
  |> fn(body) { sentinel <> body }
  |> wasi.write_stdout
}

/// Marks the start of the response payload in stdout, so a stray
/// `io:format`/print in user code can't corrupt the framing (index.js reads
/// everything after the last occurrence of this marker, up to the matching
/// closing brace — AtomVM's own runtime also prints a trailer after this).
pub const sentinel = "\n__GLOWVM__"

type Payload {
  Payload(method: String, url: String, headers: Dict(String, String), body: String)
}

fn payload_decoder() -> decode.Decoder(Payload) {
  use method <- decode.field("method", decode.string)
  use url <- decode.field("url", decode.string)
  use headers <- decode.field(
    "headers",
    decode.dict(decode.string, decode.string),
  )
  use body <- decode.field("body", decode.string)
  decode.success(Payload(method:, url:, headers:, body:))
}

/// Pure request/response bridge, without the stdin/stdout IO — this is
/// what tests drive directly.
pub fn handle(
  payload: String,
  handler: fn(wisp.Request) -> wisp.Response,
) -> String {
  case decode_request(payload) {
    Ok(req) -> handler(req) |> encode_response
    Error(message) -> encode_error(400, message)
  }
}

fn decode_request(payload: String) -> Result(wisp.Request, String) {
  use p <- result.try(
    json.parse(payload, payload_decoder())
    |> result.replace_error("invalid request payload"),
  )
  use method <- result.try(
    http.parse_method(p.method) |> result.replace_error("bad method"),
  )

  let #(path, query) = case string.split_once(p.url, "?") {
    Ok(#(path, query)) -> #(path, Some(query))
    Error(Nil) -> #(p.url, None)
  }
  let host = dict.get(p.headers, "host") |> result.unwrap("localhost")
  let headers =
    p.headers
    |> dict.to_list
    |> list.map(fn(h) { #(ascii_lowercase(h.0), h.1) })

  let secret = crypto.strong_random_bytes(64) |> base64_encode
  let connection = make_connection(bit_array.from_string(p.body), secret)

  Ok(request.Request(
    method:,
    headers:,
    body: connection,
    scheme: http.Https,
    host:,
    port: None,
    path:,
    query:,
  ))
}

/// `wisp.create_canned_connection` goes through
/// `directories.tmp_dir()` (probing `/tmp`, `/var/tmp`, `/usr/tmp` via
/// `os:type/0` and `file:read_file_info/2`) and `internal.random_slug()`
/// (base64-url encoding, another AtomVM gap) to pick a temp dir for
/// streaming multipart uploads to disk. Both are pointless here — a Worker
/// has no filesystem to stream to, so `temporary_directory` is never
/// actually read from — and a fixed literal is correct, not just easier.
fn make_connection(body: BitArray, secret: String) -> wisp.Connection {
  internal.Connection(
    reader: canned_reader(body),
    max_body_size: 8_000_000,
    max_files_size: 32_000_000,
    read_chunk_size: 1_000_000,
    secret_key_base: secret,
    temporary_directory: "./tmp/glowvm",
  )
}

fn canned_reader(data: BitArray) -> internal.Reader {
  fn(chunk_size) {
    case bit_array.byte_size(data) {
      0 -> Ok(internal.ReadingFinished)
      size -> {
        let take = int.min(chunk_size, size)
        let assert Ok(chunk) = bit_array.slice(data, 0, take)
        let assert Ok(rest) = bit_array.slice(data, take, size - take)
        Ok(internal.Chunk(chunk, canned_reader(rest)))
      }
    }
  }
}

fn encode_response(resp: wisp.Response) -> String {
  case resp.body {
    wisp.File(..) ->
      encode_error(501, "file responses are not supported on glowvm")
    body -> {
      let #(text, encoding) = encode_body(body)
      json.object([
        #("status", json.int(resp.status)),
        #("headers", json_headers(resp.headers)),
        #("body", json.string(text)),
        #("encoding", json.string(encoding)),
      ])
      |> json.to_string
    }
  }
}

fn encode_body(body: wisp.Body) -> #(String, String) {
  let bits = case body {
    wisp.Text(s) -> bit_array.from_string(s)
    wisp.Bytes(tree) -> bytes_tree.to_bit_array(tree)
    wisp.File(..) -> <<>>
  }
  case bit_array.to_string(bits) {
    Ok(s) -> #(s, "utf8")
    Error(Nil) -> #(base64_encode(bits), "base64")
  }
}

fn json_headers(headers: List(#(String, String))) -> json.Json {
  headers
  |> list.map(fn(h) {
    json.preprocessed_array([json.string(h.0), json.string(h.1)])
  })
  |> json.preprocessed_array
}

fn encode_error(status: Int, message: String) -> String {
  json.object([
    #("status", json.int(status)),
    #(
      "headers",
      json_headers([#("content-type", "text/plain; charset=utf-8")]),
    ),
    #("body", json.string(message)),
    #("encoding", json.string("utf8")),
  ])
  |> json.to_string
}

/// gleam_stdlib's own `bit_array.base64_encode` calls the OTP 26+
/// `base64:encode/2` (with an options map), which is absent from AtomVM's
/// nif table — only the plain `base64:encode/1` is there. Call that
/// directly rather than going through the broken wrapper.
@external(erlang, "base64", "encode")
fn base64_encode(bits: BitArray) -> String

@external(erlang, "erlang", "binary_to_list")
fn binary_to_list(s: String) -> List(Int)

@external(erlang, "erlang", "list_to_binary")
fn list_to_binary(l: List(Int)) -> String

/// HTTP header names are always ASCII tokens, so a full Unicode-aware
/// `string:lowercase/1` (missing from AtomVM's stdlib) isn't needed here.
fn ascii_lowercase(s: String) -> String {
  s
  |> binary_to_list
  |> list.map(fn(c) {
    case c >= 65 && c <= 90 {
      True -> c + 32
      False -> c
    }
  })
  |> list_to_binary
}
