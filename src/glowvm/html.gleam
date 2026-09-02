/// HTML helpers – port of ElixirWorkers.HTML
import gleam/dict.{type Dict}
import gleam/list
import gleam/string

@external(erlang, "erlang", "binary_to_list")
fn binary_to_list(s: String) -> List(Int)

@external(erlang, "erlang", "list_to_binary")
fn list_to_binary(l: List(Int)) -> String

/// Escape HTML entities to prevent XSS
pub fn escape(bin: String) -> String {
  bin
  |> binary_to_list
  |> list.fold("", fn(acc, code) {
    case code {
      38 -> acc <> "&amp;"
      60 -> acc <> "&lt;"
      62 -> acc <> "&gt;"
      34 -> acc <> "&quot;"
      39 -> acc <> "&#39;"
      _ -> acc <> list_to_binary([code])
    }
  })
}

/// Build an HTML tag: tag("div", dict.from_list([#("class","card")]), "content")
pub fn tag(name: String, attrs: Dict(String, String), content: String) -> String {
  "<"
  <> name
  <> encode_attrs(attrs)
  <> ">"
  <> content
  <> "</"
  <> name
  <> ">"
}

pub fn tag_simple(name: String, content: String) -> String {
  tag(name, dict.new(), content)
}

/// Build a void/self-closing tag: void_tag("input", dict.from_list([#("type","text")]))
pub fn void_tag(name: String, attrs: Dict(String, String)) -> String {
  "<" <> name <> encode_attrs(attrs) <> "/>"
}

pub fn void_tag_simple(name: String) -> String {
  void_tag(name, dict.new())
}

/// Render a list by applying a function to each item and joining
pub fn each(items: List(a), render: fn(a) -> String) -> String {
  items
  |> list.map(render)
  |> string.join("")
}

fn encode_attrs(attrs: Dict(String, String)) -> String {
  attrs
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(k, v) = pair
    " " <> k <> "=\"" <> escape(v) <> "\""
  })
  |> string.join("")
}
