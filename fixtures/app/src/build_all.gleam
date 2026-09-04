import gleam/io
import gleam/list
import glowvm/build

/// Packs every fixture module below into its own dist/<name>/app.avm, one
/// build.build() call per module — run with `gleam run -m build_all`
/// (module_name lets one project host many single-purpose entrypoints
/// instead of cramming every case into one handler).
const modules = [
  "basic_get",
  "not_found",
  "query_param",
  "bytes_body",
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

pub fn main() {
  list.each(modules, fn(name) {
    let output_dir = "dist/" <> name
    case build.build(output_dir:, module_name: name) {
      Ok(_) -> io.println("build ok for " <> name)
      Error(e) -> {
        io.println("FAIL " <> name <> ": " <> e)
        panic as "fixture build failed"
      }
    }
  })
}
