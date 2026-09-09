import fixture_check
import glowvm
import gleam/option
import gleam/order
import gleam/string
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let codepoints = string.to_utf_codepoints("hello world")
  let assert Ok(codepoint) = string.utf_codepoint(104)

  fixture_check.run([
    #(
      "string.append(hello, world)",
      string.append("hello", "world") == "helloworld",
    ),
    #("string.byte_size(hello)", string.byte_size("hello") == 5),
    #("string.capitalise(hello)", string.capitalise("hello") == "Hello"),
    #("string.compare(a, b)", string.compare("a", "b") == order.Lt),
    #(
      "string.concat([hello, world])",
      string.concat(["hello", "world"]) == "helloworld",
    ),
    #(
      "string.contains(hello world, wor)",
      string.contains("hello world", "wor") == True,
    ),
    #(
      "string.crop(hello world, wor)",
      string.crop("hello world", "wor") == "world",
    ),
    #(
      "string.drop_end(hello world, 3)",
      string.drop_end("hello world", 3) == "hello wo",
    ),
    #(
      "string.drop_start(hello world, 3)",
      string.drop_start("hello world", 3) == "lo world",
    ),
    #(
      "string.ends_with(hello world, world)",
      string.ends_with("hello world", "world") == True,
    ),
    #(
      "string.first(hello world)",
      string.first("hello world") == Ok("h"),
    ),
    #(
      "string.from_utf_codepoints([])",
      string.from_utf_codepoints([]) == "",
    ),
    #(
      "string.inspect(hello)",
      string.inspect("hello") == "\"hello\"",
    ),
    #("string.is_empty()", string.is_empty("") == True),
    #(
      "string.join([hello, world], , )",
      string.join(["hello", "world"], ", ") == "hello, world",
    ),
    #("string.last(hello world)", string.last("hello world") == Ok("d")),
    #("string.length(hello world)", string.length("hello world") == 11),
    #("string.lowercase(HELLO)", string.lowercase("HELLO") == "hello"),
    #(
      "string.pad_end(hello, 10, sp)",
      string.pad_end("hello", 10, " ") == "hello     ",
    ),
    #(
      "string.pad_start(hello, 10, sp)",
      string.pad_start("hello", 10, " ") == "     hello",
    ),
    #(
      "string.pop_grapheme(hello)",
      string.pop_grapheme("hello") == Ok(#("h", "ello")),
    ),
    #(
      "string.remove_prefix(hello world, hello )",
      string.remove_prefix("hello world", "hello ") == "world",
    ),
    #(
      "string.remove_suffix(hello world,  world)",
      string.remove_suffix("hello world", " world") == "hello",
    ),
    #(
      "string.repeat(hello, 3)",
      string.repeat("hello", 3) == "hellohellohello",
    ),
    #(
      "string.replace(hello world, world, there)",
      string.replace("hello world", "world", "there") == "hello there",
    ),
    #(
      "string.reverse(hello world)",
      string.reverse("hello world") == "dlrow olleh",
    ),
    #(
      "string.slice(hello world, 0, 5)",
      string.slice("hello world", 0, 5) == "hello",
    ),
    #(
      "string.split(hello world,  )",
      string.split("hello world", " ") == ["hello", "world"],
    ),
    #(
      "string.split_once(hello world,  )",
      string.split_once("hello world", " ") == Ok(#("hello", "world")),
    ),
    #(
      "string.starts_with(hello world, hello)",
      string.starts_with("hello world", "hello") == True,
    ),
    #(
      "string.to_graphemes(hello world)",
      string.to_graphemes("hello world")
        == ["h", "e", "l", "l", "o", " ", "w", "o", "r", "l", "d"],
    ),
    #(
      "string.to_option(hello)",
      string.to_option("hello") == option.Some("hello"),
    ),
    #(
      "string.to_utf_codepoints round-trips",
      string.from_utf_codepoints(codepoints) == "hello world",
    ),
    #(
      "string.trim(  hello world  )",
      string.trim("  hello world  ") == "hello world",
    ),
    #(
      "string.trim_end(  hello world  )",
      string.trim_end("  hello world  ") == "  hello world",
    ),
    #(
      "string.trim_start(  hello world  )",
      string.trim_start("  hello world  ") == "hello world  ",
    ),
    #("string.uppercase(hello)", string.uppercase("hello") == "HELLO"),
    #(
      "string.utf_codepoint_to_int(104)",
      string.utf_codepoint_to_int(codepoint) == 104,
    ),
  ])
}
