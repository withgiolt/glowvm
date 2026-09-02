/// WASI bridge – mirrors ElixirWorkers.Wasi / AtomVM.Wasi
/// For Gleam we re-export Erlang functions from host_io.erl
/// host_io is registered in atomvm-wasi/src/platform_nifs.c as Gleam NIFs:
///   "host_io:read_stdin/0" -> nif_gleam_read_stdin (returns <<>> on empty)
///   "host_io:write_stdout/1" -> nif_gleam_write_stdout
/// On host Erlang (gleam run / gleam test) host_io.erl uses io:get_line fallback.

@external(erlang, "host_io", "read_stdin")
pub fn read_stdin() -> String

@external(erlang, "host_io", "write_stdout")
pub fn write_stdout(data: String) -> Nil
