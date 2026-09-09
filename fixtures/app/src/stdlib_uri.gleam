import fixture_check
import glowvm
import gleam/option.{None, Some}
import gleam/uri
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let assert Ok(parsed) = uri.parse("https://example.com/path?a=1#frag")

  fixture_check.run([
    #(
      "uri.empty",
      uri.empty
        == uri.Uri(
          scheme: None,
          userinfo: None,
          host: None,
          port: None,
          path: "",
          query: None,
          fragment: None,
        ),
    ),
    #(
      "uri.parse(https://example.com/path?a=1#frag)",
      parsed
        == uri.Uri(
          scheme: Some("https"),
          userinfo: None,
          host: Some("example.com"),
          port: None,
          path: "/path",
          query: Some("a=1"),
          fragment: Some("frag"),
        ),
    ),
    #(
      "uri.parse_query(a=1&b=2)",
      uri.parse_query("a=1&b=2") == Ok([#("a", "1"), #("b", "2")]),
    ),
    #(
      "uri.query_to_string([a=1, b=2])",
      uri.query_to_string([#("a", "1"), #("b", "2")]) == "a=1&b=2",
    ),
    #(
      "uri.percent_encode(100% great)",
      uri.percent_encode("100% great") == "100%25%20great",
    ),
    #(
      "uri.percent_decode(100%25%20great)",
      uri.percent_decode("100%25%20great") == Ok("100% great"),
    ),
    #(
      "uri.path_segments(/users/1)",
      uri.path_segments("/users/1") == ["users", "1"],
    ),
    #(
      "uri.to_string(parsed)",
      uri.to_string(parsed) == "https://example.com/path?a=1#frag",
    ),
    #(
      "uri.origin(parsed)",
      uri.origin(parsed) == Ok("https://example.com"),
    ),
    #("uri.merge(parsed, parsed)", uri.merge(parsed, parsed) == Ok(parsed)),
  ])
}
