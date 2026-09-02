import glowvm
import lustre/element
import lustre/element/html
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  element.to_document_string(element())
  |> wisp.html_response(200)
}

pub fn element() {
  html.html([], [
    html.head([], []),
    html.body([], [html.h1([], [html.text("hello from glowvm")])]),
  ])
}
