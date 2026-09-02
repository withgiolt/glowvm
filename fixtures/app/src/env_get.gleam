import envie
import glowvm
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  let secret_env = envie.get_string("SECRET_KEY", "NONE")

  wisp.ok()
  |> wisp.string_body(secret_env)
}
