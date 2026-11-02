import glowvm
import wisp

/// 204 must reach the client without a body: Response rejects one.
pub fn start() {
  glowvm.serve(fn(_req) { wisp.no_content() })
}
