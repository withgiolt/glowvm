/// URL helpers – Gleam port of ElixirWorkers.URL
/// Covers: parse_path, split_path, decode_query, percent_decode, match_path

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

@external(erlang, "erlang", "binary_to_list")
fn binary_to_list(s: String) -> List(Int)

@external(erlang, "erlang", "list_to_binary")
fn list_to_binary(l: List(Int)) -> String

// ---------------------------------------------------------------------------
// Parsed path
// ---------------------------------------------------------------------------

pub type ParsedPath {
  ParsedPath(path: String, query_string: String)
}

/// Split URL into path and query_string
/// parse_path("/posts/42?page=2") -> ParsedPath("/posts/42", "page=2")
pub fn parse_path(url: String) -> ParsedPath {
  case string.split_once(url, "?") {
    Ok(#(p, q)) -> ParsedPath(path: p, query_string: q)
    Error(Nil) -> ParsedPath(path: url, query_string: "")
  }
}

/// Split path into segments: "/posts/42" -> ["posts", "42"], "/" -> []
pub fn split_path(path: String) -> List(String) {
  path
  |> string.split("/")
  |> list.filter(fn(seg) { seg != "" })
}

// ---------------------------------------------------------------------------
// Query decoding
// ---------------------------------------------------------------------------

/// Decode query string: "a=1&b=hello+world" -> dict
pub fn decode_query(qs: String) -> Dict(String, String) {
  case qs {
    "" -> dict.new()
    _ -> {
      qs
      |> string.split("&")
      |> list.fold(dict.new(), fn(acc, pair) {
        case pair {
          "" -> acc
          _ ->
            case string.split_once(pair, "=") {
              Ok(#(k, v)) -> {
                let dk = percent_decode(k)
                let dv = percent_decode(v)
                dict.insert(acc, dk, dv)
              }
              Error(Nil) -> {
                let dk = percent_decode(pair)
                dict.insert(acc, dk, "")
              }
            }
        }
      })
    }
  }
}

/// Percent-decode: "hello%20world" -> "hello world", "+" -> " "
pub fn percent_decode(bin: String) -> String {
  bin
  |> binary_to_list
  |> do_percent_bytes([])
  |> list_to_binary
}

fn do_percent_bytes(chars: List(Int), acc: List(Int)) -> List(Int) {
  case chars {
    [] -> list.reverse(acc)
    [37, h1, h2, ..rest] -> {
      // 37 == '%'
      case char_to_hex_int(h1), char_to_hex_int(h2) {
        Some(hi), Some(lo) -> {
          let byte = hi * 16 + lo
          do_percent_bytes(rest, [byte, ..acc])
        }
        _, _ -> do_percent_bytes([h1, h2, ..rest], [37, ..acc])
      }
    }
    [43, ..rest] -> do_percent_bytes(rest, [32, ..acc]) // '+' -> ' '
    [c, ..rest] -> do_percent_bytes(rest, [c, ..acc])
  }
}

fn char_to_hex_int(c: Int) -> Option(Int) {
  case c {
    c if c >= 48 && c <= 57 -> Some(c - 48)
    c if c >= 97 && c <= 102 -> Some(c - 97 + 10)
    c if c >= 65 && c <= 70 -> Some(c - 65 + 10)
    _ -> None
  }
}

// ---------------------------------------------------------------------------
// Path matching with :param and * wildcard
// ---------------------------------------------------------------------------

/// Match path segments against a pattern with :param captures.
/// match_path(["posts","42"], ["posts",":id"]) -> Ok(dict from "id"->"42")
/// match_path(["posts"], ["posts",":id"]) -> Error(Nil)
pub fn match_path(
  segments: List(String),
  pattern: List(String),
) -> Result(Dict(String, String), Nil) {
  do_match(segments, pattern, dict.new())
}

fn do_match(
  segs: List(String),
  pats: List(String),
  params: Dict(String, String),
) -> Result(Dict(String, String), Nil) {
  case segs, pats {
    [], [] -> Ok(params)
    _, [] -> Error(Nil)
    [], _ -> Error(Nil)
    [seg, ..rest_segs], [pat, ..rest_pats] -> {
      case pat {
        "*" -> {
          let remaining = string.join([seg, ..rest_segs], "/")
          Ok(dict.insert(params, "*", remaining))
        }
        _ ->
          case string.starts_with(pat, ":") {
            True -> {
              let name = string.drop_start(pat, 1)
              do_match(rest_segs, rest_pats, dict.insert(params, name, seg))
            }
            False ->
              case seg == pat {
                True -> do_match(rest_segs, rest_pats, params)
                False -> Error(Nil)
              }
          }
      }
    }
  }
}
