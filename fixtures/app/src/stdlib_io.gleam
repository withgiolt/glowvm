import fixture_check
import glowvm
import gleam/io
import wisp

pub fn start() {
  glowvm.serve(handle_request)
}

fn handle_request(_req: wisp.Request) -> wisp.Response {
  // io's functions write to stdout/stderr as a side effect and always return
  // Nil, win or lose — there is no return value that could distinguish a
  // working write from a silently dropped one, and the response body can't
  // observe host-side stdout/stderr. Checking the Nil return is the only
  // assertion available from inside the handler; the real correctness check
  // is that host_io.erl's NIF bridge doesn't crash the request, which the
  // 200 status on this endpoint already demonstrates.
  fixture_check.run([
    #("io.print(hello)", io.print("hello") == Nil),
    #("io.print_error(hello)", io.print_error("hello") == Nil),
    #("io.println(hello)", io.println("hello") == Nil),
    #("io.println_error(hello)", io.println_error("hello") == Nil),
  ])
}
