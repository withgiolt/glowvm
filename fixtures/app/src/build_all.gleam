import filepath
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplifile

const modules = [
  "basic_get",
  "not_found",
  "query_param",
  "bytes_body",
  "echo_body",
  "no_content",
  "file_body",
  "env_get",
  "lustre_html",
  "stdlib_string",
  "stdlib_bool",
  "stdlib_int",
  "stdlib_float",
  "stdlib_list",
  "stdlib_option",
  "stdlib_result",
  "stdlib_order",
  "stdlib_pair",
  "stdlib_dict",
  "stdlib_set",
  "stdlib_bit_array",
  "stdlib_string_tree",
  "stdlib_uri",
  "stdlib_function",
  "stdlib_io",
  "stdlib_bytes_tree",
  "stdlib_dynamic",
]

const runtime_dir = "../../priv"

const runtime_files = ["glowvm.wasm", "index.js", "index.min.js"]

pub fn main() {
  list.each(modules, fn(name) {
    case pack(name, "dist/" <> name) {
      Ok(Nil) -> io.println("build ok for " <> name)
      Error(e) -> {
        io.println("FAIL " <> name <> ": " <> e)
        panic as "fixture build failed"
      }
    }
  })
}

fn pack(start_module: String, output_dir: String) -> Result(Nil, String) {
  let stdlib_dir = filepath.join(runtime_dir, "stdlib")

  use stdlib <- result.try(
    simplifile.read_directory(stdlib_dir)
    |> result.replace_error("cannot read " <> stdlib_dir),
  )
  use compiled <- result.try(
    simplifile.get_files("build/dev/erlang")
    |> result.replace_error("cannot list the compiled modules"),
  )
  use _ <- result.try(
    simplifile.create_directory_all(output_dir)
    |> result.replace_error("cannot create " <> output_dir),
  )

  let beams =
    list.append(
      list.filter(compiled, fn(file) {
        is_beam(file) && !list.contains(string.split(file, "/"), "priv")
      }),
      stdlib
        |> list.filter(is_beam)
        |> list.map(filepath.join(stdlib_dir, _)),
    )

  use _ <- result.try(
    packbeam_create(filepath.join(output_dir, "app.avm"), start_module, beams)
    |> result.map_error(fn(e) { "packbeam failed: " <> string.inspect(e) }),
  )

  list.try_each(runtime_files, fn(file) {
    simplifile.copy_file(
      filepath.join(runtime_dir, file),
      filepath.join(output_dir, file),
    )
    |> result.replace_error("cannot copy " <> file)
  })
}

fn is_beam(path: String) -> Bool {
  filepath.extension(path) == Ok("beam")
}

@external(erlang, "orbital_ffi", "packbeam_create")
fn packbeam_create(
  output_path: String,
  start_module: String,
  beam_files: List(String),
) -> Result(Nil, String)
