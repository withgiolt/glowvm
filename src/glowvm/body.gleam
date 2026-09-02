/// Body parsing – port of ElixirWorkers.Body
import gleam/dict.{type Dict}
import gleam/json
import gleam/dynamic/decode
import gleam/list
import gleam/string
import glowvm/url

@external(erlang, "erlang", "binary_to_list")
fn binary_to_list(s: String) -> List(Int)

@external(erlang, "erlang", "list_to_binary")
fn list_to_binary(l: List(Int)) -> String

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

/// Parse a request body based on content-type header.
pub fn parse(body: String, content_type: String) -> String {
  let ct = ascii_lowercase(content_type)
  case string.starts_with(ct, "application/x-www-form-urlencoded") {
    True -> {
      // For body parsing we keep raw string for now, but also provide helper
      // The parsed form is available via parse_urlencoded if needed
      body
    }
    False ->
      case string.starts_with(ct, "application/json") {
        True ->
          case parse_json(body) {
            Ok(_) -> body
            Error(_) -> body
          }
        False -> body
      }
  }
}

/// Parse URL-encoded form body: "name=Alice&age=30" -> dict
pub fn parse_urlencoded(body: String) -> Dict(String, String) {
  url.decode_query(body)
}

/// Parse JSON body – returns Ok(Dict) or Error if empty/invalid.
/// For base port we expose raw string; this helper shows JSON decoding works.
pub fn parse_json(body: String) -> Result(Dict(String, String), json.DecodeError) {
  case body {
    "" -> Ok(dict.new())
    _ -> {
      let decoder = decode.dict(decode.string, decode.string)
      json.parse(from: body, using: decoder)
    }
  }
}
