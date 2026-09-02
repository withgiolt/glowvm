import glowvm/internal/bridge
import wisp

/// Run a wisp handler as a glowvm app. Call this from `start/0`:
///
/// ```gleam
/// pub fn start() {
///   glowvm.serve(handle_request)
/// }
///
/// fn handle_request(req: wisp.Request) -> wisp.Response {
///   wisp.ok() |> wisp.string_body("hello")
/// }
/// ```
pub fn serve(handler: fn(wisp.Request) -> wisp.Response) -> Nil {
  bridge.serve(handler)
}
