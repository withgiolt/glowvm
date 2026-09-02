import filepath
import gleam/dict
import gleam/json
import gleam/list
import gleam/package_interface
import gleam/result
import gleam/string
import orbital/internal/executable.{type ExecutablePath}
import orbital/internal/project
import simplifile

const stdlib_beams = [
  "binary.beam",
  "lists.beam",
  "maps.beam",
  "unicode.beam",
  "string.beam",
]

/// Compile the current Gleam project, pack `module_name`'s `start/0` as the
/// AtomVM entrypoint, and write `app.avm`, `glowvm.wasm`, and `index.js`
/// into `output_dir`.
///
/// `module_name` defaults to the project name for a normal single-app
/// project (`gleam.toml`'s `name = "my_app"` with `src/my_app.gleam`
/// exporting `start/0`) — pass a different module when a project hosts
/// several independent entrypoints, e.g. a fixtures project with one small
/// `start/0` per module under test.
pub fn build(
  output_dir output_dir: String,
  module_name module_name: String,
) -> Result(String, String) {
  use gleam <- result.try(
    executable.find("gleam") |> result.replace_error("cannot find gleam"),
  )
  use proj <- result.try(
    project.load()
    |> result.map_error(fn(e) { "cannot load project: " <> string.inspect(e) }),
  )

  use Nil <- result.try(compile(gleam, proj))
  use Nil <- result.try(validate_entrypoint(gleam, proj, module_name))
  use Nil <- result.try(
    simplifile.create_directory_all(output_dir)
    |> result.replace_error("cannot create output directory " <> output_dir),
  )

  let output_path = filepath.join(output_dir, "app.avm")

  use Nil <- result.try(ensure_stdlib(proj))
  use Nil <- result.try(bundle_beam_files(proj, output_path, module_name))
  use Nil <- result.try(
    ensure_wasm(proj, output_dir)
    |> result.replace_error("cannot copy glowvm.wasm"),
  )
  use Nil <- result.try(
    ensure_index_js(proj, output_dir)
    |> result.replace_error("cannot copy index.js"),
  )

  Ok(output_path)
}

fn compile(
  gleam: ExecutablePath,
  proj: project.Project,
) -> Result(Nil, String) {
  case executable.run(gleam, proj.root_directory, ["build"]) {
    Ok(0) -> Ok(Nil)
    Ok(_) -> Error("gleam build failed")
    Error(_) -> Error("cannot spawn gleam")
  }
}

fn validate_entrypoint(
  gleam: ExecutablePath,
  proj: project.Project,
  module_name: String,
) -> Result(Nil, String) {
  let file =
    filepath.join(proj.root_directory, "build/.tmp_package_interface.json")
  use _ <- result.try(
    executable.run(gleam, proj.root_directory, [
      "export",
      "package-interface",
      "--out",
      file,
    ])
    |> result.replace_error("cannot run gleam export"),
  )
  use content <- result.try(
    simplifile.read(file)
    |> result.map_error(fn(_) { "cannot read package_interface" }),
  )
  let _ = simplifile.delete(file)
  use iface <- result.try(
    json.parse(content, package_interface.decoder())
    |> result.map_error(fn(_) { "cannot parse package_interface" }),
  )
  use mod <- result.try(
    dict.get(iface.modules, module_name)
    |> result.replace_error("missing entrypoint module " <> module_name),
  )
  use fun <- result.try(
    dict.get(mod.functions, "start")
    |> result.replace_error(
      "missing start/0 in "
      <> module_name
      <> " — add `pub fn start() { glowvm.serve(your_handler) }`",
    ),
  )
  case fun.parameters {
    [] -> Ok(Nil)
    _ -> Error("start/0 must take no arguments — call glowvm.serve(handler) from it, not the other way round")
  }
}

/// Where glowvm's own `priv/` ends up in a consumer's build tree. Hex
/// dependencies (the normal case) are staged at `build/packages/glowvm/`;
/// a `path`-dependency (glowvm's own smoke test, or developing against an
/// unpublished checkout) only ever produces `build/dev/erlang/glowvm/`, so
/// fall back to that rather than requiring a manual `build/packages/glowvm`
/// symlink for that case.
fn glowvm_priv_dir(proj: project.Project) -> String {
  let hex_dir = filepath.join(proj.root_directory, "build/packages/glowvm")
  case simplifile.is_directory(hex_dir) {
    Ok(True) -> filepath.join(hex_dir, "priv")
    _ ->
      filepath.join(proj.root_directory, "build/dev/erlang/glowvm/priv")
  }
}

/// Copy minimal AtomVM stdlib beams into build/dev/erlang/atomvm_extra
/// so orbital's `list_beam_files` (which scans build/dev/erlang recursively)
/// will see them, but we avoid shadowing host-critical modules like
/// gen_server, application, etc. This mirrors AtomVM's `resolve_stdlib_deps`
/// tree-shaking but with a fixed minimal set that is sufficient for the
/// base worker (binary, maps, lists, unicode, string).
fn ensure_stdlib(proj: project.Project) -> Result(Nil, String) {
  let dest = filepath.join(proj.root_directory, "build/dev/erlang/atomvm_extra")
  let _ = simplifile.create_directory_all(dest)
  let src = filepath.join(glowvm_priv_dir(proj), "stdlib")
  list.try_each(stdlib_beams, fn(beam) {
    let from = filepath.join(src, beam)
    let to = filepath.join(dest, beam)
    case simplifile.read_bits(from) {
      Ok(bits) ->
        simplifile.write_bits(to, bits)
        |> result.map_error(fn(_) { "copy " <> beam <> " failed" })
      Error(_) -> Ok(Nil)
      // ignore missing
    }
  })
}

fn bundle_beam_files(
  proj: project.Project,
  output_path: String,
  module_name: String,
) -> Result(Nil, String) {
  use files <- result.try(
    list_beam_files(proj)
    |> result.map_error(fn(e) { "cannot list beams: " <> string.inspect(e) }),
  )
  packbeam_create(output_path, module_name, files)
  |> result.map_error(fn(e) { "packbeam failed: " <> string.inspect(e) })
}

fn list_beam_files(
  proj: project.Project,
) -> Result(List(String), simplifile.FileError) {
  let build_dir = filepath.join(proj.root_directory, "build/dev/erlang")
  use files <- result.try(simplifile.get_files(build_dir))
  Ok(list.filter(files, fn(f) { filepath.extension(f) == Ok("beam") }))
}

@external(erlang, "orbital_ffi", "packbeam_create")
fn packbeam_create(
  output_path: String,
  start_module: String,
  beam_files: List(String),
) -> Result(Nil, String)

fn ensure_wasm(
  proj: project.Project,
  output_dir: String,
) -> Result(Nil, simplifile.FileError) {
  let dest = filepath.join(output_dir, "glowvm.wasm")
  case simplifile.is_file(dest) {
    Ok(True) -> Ok(Nil)
    _ -> {
      let src = filepath.join(glowvm_priv_dir(proj), "glowvm.wasm")
      case simplifile.is_file(src) {
        Ok(True) -> {
          use bits <- result.try(simplifile.read_bits(src))
          simplifile.write_bits(dest, bits)
        }
        _ -> Ok(Nil)
      }
    }
  }
}

fn ensure_index_js(
  proj: project.Project,
  output_dir: String,
) -> Result(Nil, simplifile.FileError) {
  let dest = filepath.join(output_dir, "index.js")
  let src = filepath.join(glowvm_priv_dir(proj), "index.js")
  case simplifile.is_file(src) {
    Ok(True) -> {
      use bits <- result.try(simplifile.read_bits(src))
      simplifile.write_bits(dest, bits)
    }
    _ -> Ok(Nil)
  }
}
