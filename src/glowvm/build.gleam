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

  use _ <- result.try(compile(gleam, proj))
  use _ <- result.try(validate_entrypoint(gleam, proj, module_name))
  use _ <- result.try(
    simplifile.create_directory_all(output_dir)
    |> result.replace_error("cannot create output directory " <> output_dir),
  )

  let output_path = filepath.join(output_dir, "app.avm")

  use _ <- result.try(ensure_stdlib(proj))
  use _ <- result.try(bundle_beam_files(proj, output_path, module_name))
  use _ <- result.try(
    ensure_wasm(proj, output_dir)
    |> result.replace_error("cannot copy glowvm.wasm"),
  )
  use _ <- result.try(
    ensure_index_js(proj, output_dir)
    |> result.replace_error("cannot copy index.js"),
  )
  use _ <- result.try(
    ensure_deno_loaders(proj, output_dir)
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
    _ ->
      Error(
        "start/0 must take no arguments — call glowvm.serve(handler) from it, not the other way round",
      )
  }
}

// glowvm is consumed both as a hex dependency (build/packages/glowvm) and,
// within this repo, as a path dependency (build/dev/erlang/glowvm) — prefer
// the hex layout when present, since that's what real consumer apps have.
fn glowvm_priv_dir(proj: project.Project) -> String {
  let hex_dir = filepath.join(proj.root_directory, "build/packages/glowvm")
  case simplifile.is_directory(hex_dir) {
    Ok(True) -> filepath.join(hex_dir, "priv")
    _ -> filepath.join(proj.root_directory, "build/dev/erlang/glowvm/priv")
  }
}

// Copies every curated priv/stdlib beam into atomvm_extra, which
// bundle_beam_files then packs. Deletes the destination first so a beam
// removed from priv/stdlib (e.g. base64, replaced by a shim) can't linger
// from a previous build.
fn ensure_stdlib(proj: project.Project) -> Result(Nil, String) {
  let dest = filepath.join(proj.root_directory, "build/dev/erlang/atomvm_extra")
  let _ = simplifile.delete(dest)
  let _ = simplifile.create_directory_all(dest)
  let src = filepath.join(glowvm_priv_dir(proj), "stdlib")

  use entries <- result.try(
    simplifile.read_directory(src)
    |> result.replace_error("cannot read stdlib dir " <> src),
  )
  let beams =
    list.filter(entries, fn(entry) { filepath.extension(entry) == Ok("beam") })

  use _ <- result.try(case beams {
    [] -> Error("no .beam files found in " <> src)
    _ -> Ok(Nil)
  })

  beams
  |> list.try_each(fn(beam) {
    let from = filepath.join(src, beam)
    let to = filepath.join(dest, beam)
    use bits <- result.try(
      simplifile.read_bits(from)
      |> result.replace_error("read " <> beam <> " failed"),
    )
    simplifile.write_bits(to, bits)
    |> result.replace_error("copy " <> beam <> " failed")
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
  Ok(
    list.filter(files, fn(f) {
      filepath.extension(f) == Ok("beam") && !is_under_priv(f)
    }),
  )
}

fn is_under_priv(path: String) -> Bool {
  string.split(path, "/") |> list.contains("priv")
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
  let src = filepath.join(glowvm_priv_dir(proj), "glowvm.wasm")
  case simplifile.is_file(src) {
    Ok(True) -> {
      use bits <- result.try(simplifile.read_bits(src))
      simplifile.write_bits(dest, bits)
    }
    _ -> Ok(Nil)
  }
}

fn ensure_index_js(
  proj: project.Project,
  output_dir: String,
) -> Result(List(Nil), simplifile.FileError) {
  let files_list = [
    #(
      filepath.join(output_dir, "index.js"),
      filepath.join(glowvm_priv_dir(proj), "index.js"),
    ),
    #(
      filepath.join(output_dir, "index.min.js"),
      filepath.join(glowvm_priv_dir(proj), "index.min.js"),
    ),
  ]

  list.try_map(files_list, fn(file) {
    case simplifile.is_file(file.1) {
      Ok(True) -> {
        use bits <- result.try(simplifile.read_bits(file.1))
        simplifile.write_bits(file.0, bits)
      }
      _ -> Ok(Nil)
    }
  })
}

fn ensure_deno_loaders(
  proj: project.Project,
  output_dir: String,
) -> Result(List(Nil), simplifile.FileError) {
  let files_list = [
    #(
      filepath.join(output_dir, "app.avm.loader.mjs"),
      filepath.join(glowvm_priv_dir(proj), "app.avm.loader.mjs"),
    ),
    #(
      filepath.join(output_dir, "glowvm.wasm.loader.mjs"),
      filepath.join(glowvm_priv_dir(proj), "glowvm.wasm.loader.mjs"),
    ),
    #(
      filepath.join(output_dir, "deno.json"),
      filepath.join(glowvm_priv_dir(proj), "deno.json"),
    ),
  ]

  list.try_map(files_list, fn(file) {
    case simplifile.is_file(file.1) {
      Ok(True) -> {
        use bits <- result.try(simplifile.read_bits(file.1))
        simplifile.write_bits(file.0, bits)
      }
      _ -> Ok(Nil)
    }
  })
}
