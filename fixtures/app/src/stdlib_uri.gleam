import glowvm
import gleam/uri
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // Insert all uri functions here
  let assert Ok(parsed) = uri.parse("https://example.com/path?a=1#frag")

  let _ = uri.empty
  let _ = uri.parse_query("a=1&b=2")
  // let _ = uri.query_to_string([#("a", "1"), #("b", "2")])
  let _ = uri.percent_encode("100% great")
  let _ = uri.percent_decode("100%25%20great")
  let _ = uri.path_segments("/users/1")
  let _ = uri.to_string(parsed)
  let _ = uri.origin(parsed)
  let _ = uri.merge(parsed, parsed)

  wisp.ok() |> wisp.string_body("OK")
}
