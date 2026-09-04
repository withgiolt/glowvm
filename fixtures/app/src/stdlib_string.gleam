import glowvm
import gleam/string
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all string functions here
  let _ = string.append("hello", "world")
  let _ = string.byte_size("hello")
  // let _ = string.capitalise("hello")
  let _ = string.compare("a", "b")
  let _ = string.concat(["hello", "world"])
  let _ = string.contains("hello world", "wor")
  let _ = string.crop("hello world", "wor")
  // let _ = string.drop_end("hello world", 3)
  // let _ = string.drop_start("hello world", 3)
  let _ = string.ends_with("hello world", "world")
  // let _ = string.first("hello world")
  let _ = string.from_utf_codepoints([])
  let _ = string.inspect("hello")
  let _ = string.is_empty("")
  let _ = string.join(["hello", "world"], ", ")
  // let _ = string.last("hello world")
  let _ = string.length("hello world")
  // let _ = string.lowercase("HELLO")
  let _ = string.pad_end("hello", 10, " ")
  let _ = string.pad_start("hello", 10, " ")
  // let _ = string.pop_grapheme("hello")
  let _ = string.remove_prefix("hello world", "hello ")
  let _ = string.remove_suffix("hello world", " world")
  let _ = string.repeat("hello", 3)
  // let _ = string.replace("hello world", "world", "there")
  // let _ = string.reverse("hello world")
  // let _ = string.slice("hello world", 0, 5)
  let _ = string.split("hello world", " ")
  let _ = string.split_once("hello world", " ")
  let _ = string.starts_with("hello world", "hello")
  // let _ = string.to_graphemes("hello world")
  let _ = string.to_option("hello")
  let _ = string.to_utf_codepoints("hello world")
  // let _ = string.trim("  hello world  ")
  // let _ = string.trim_end("  hello world  ")
  let _ = string.trim_start("  hello world  ")
  // let _ = string.uppercase("hello")
  let assert Ok(codepoint) = string.utf_codepoint(104)
  let _ = string.utf_codepoint_to_int(codepoint)

  wisp.ok() |> wisp.string_body("OK")
}
