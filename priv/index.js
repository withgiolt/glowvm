import wasm from "./glowvm.wasm";
import avm from "./app.avm";

const encoder = new TextEncoder(),
  decoder = new TextDecoder();
let cachedAvmBytes = null;
const getAvm = () => (cachedAvmBytes ??= new Uint8Array(avm));

class WasmExit extends Error {
  constructor(code) {
    super();
    this.code = code;
  }
}

const stubOk = () => 0,
  stubNotSupported = () => 52;
const envStubs = {
  dist_send_message: stubOk,
  dist_send_unlink_id_ack: stubOk,
  dist_send_payload_exit: stubOk,
  ets_delete_owned_tables: stubOk,
  ets_init: stubOk,
  ets_destroy: stubOk,
  dist_spawn_reply: stubOk,
  dist_monitor: stubOk,
  ets_delete: stubOk,
  ets_delete_table: stubOk,
  ets_insert: stubOk,
  jit_debug_unregister_code: stubOk,
  ets_create_table_maybe_gc: stubOk,
  ets_update_counter_maybe_gc: stubOk,
  dist_send_link: stubOk,
  dist_send_unlink_id: stubOk,
  ets_lookup_maybe_gc: stubOk,
  ets_lookup_element_maybe_gc: stubOk,
};

// --- WASI Runtime ---

function mkWasi(stdin, args, env = {}) {
  const stdinBytes = encoder.encode(stdin);
  let stdinPos = 0,
    stdoutBuf = new Uint8Array(65536),
    stdoutLen = 0;
  const files = new Map(),
    openFiles = new Map();
  let nextFd = 4,
    memory;

  const envEntries = Object.entries(env).map(([k, val]) => `${k}=${val}\0`);

  const dataView = () => new DataView(memory.buffer);
  const bytes = () => new Uint8Array(memory.buffer);
  const resolvePath = (pathPtr, pathLen) => {
    let path = decoder.decode(bytes().subarray(pathPtr, pathPtr + pathLen));
    if (path[0] === "." && path[1] === "/") path = path.substring(2);
    else if (path[0] === "/") path = path.substring(1);
    return path;
  };

  return {
    setMem(m) {
      memory = m;
    },
    addFile(path, data) {
      files.set(path, data);
    },
    stdout() {
      return decoder.decode(stdoutBuf.subarray(0, stdoutLen));
    },
    imports: {
      args_get(argvPtr, argBufPtr) {
        const view = dataView(),
          buf = bytes();
        for (const arg of args) {
          view.setUint32(argvPtr, argBufPtr, true);
          argvPtr += 4;
          const encoded = encoder.encode(arg + "\0");
          buf.set(encoded, argBufPtr);
          argBufPtr += encoded.length;
        }
        return 0;
      },
      args_sizes_get(countPtr, sizePtr) {
        const view = dataView();
        let totalSize = 0;
        for (const arg of args) totalSize += arg.length + 1;
        view.setUint32(countPtr, args.length, true);
        view.setUint32(sizePtr, totalSize, true);
        return 0;
      },
      clock_time_get(_, __, resultPtr) {
        dataView().setBigUint64(resultPtr, BigInt(Date.now()) * 1000000n, true);
        return 0;
      },
      clock_res_get(_, resultPtr) {
        dataView().setBigUint64(resultPtr, 1000000n, true);
        return 0;
      },
      environ_get(environPtr, environBufPtr) {
        const view = dataView(),
          buf = bytes();
        for (const entry of envEntries) {
          view.setUint32(environPtr, environBufPtr, true);
          environPtr += 4;
          const encoded = encoder.encode(entry);
          buf.set(encoded, environBufPtr);
          environBufPtr += encoded.length;
        }
        return 0;
      },
      environ_sizes_get(countPtr, sizePtr) {
        const view = dataView();
        let totalSize = 0;
        for (const entry of envEntries) totalSize += entry.length;
        view.setUint32(countPtr, envEntries.length, true);
        view.setUint32(sizePtr, totalSize, true);
        return 0;
      },
      fd_close(fd) {
        openFiles.delete(fd);
        return 0;
      },
      fd_fdstat_get(fd, resultPtr) {
        const view = dataView();
        bytes().fill(0, resultPtr, resultPtr + 24);
        if (fd <= 2) view.setUint8(resultPtr, 2);
        else if (fd === 3) view.setUint8(resultPtr, 3);
        else if (openFiles.has(fd)) view.setUint8(resultPtr, 4);
        else return 8;
        view.setBigUint64(resultPtr + 8, 0xffffffffffffffffn, true);
        view.setBigUint64(resultPtr + 16, 0xffffffffffffffffn, true);
        return 0;
      },
      fd_read(fd, iovsPtr, iovsLen, resultPtr) {
        const view = dataView(),
          buf = bytes();
        let total = 0;
        for (let i = 0; i < iovsLen; i++) {
          const ptr = view.getUint32(iovsPtr + i * 8, true),
            len = view.getUint32(iovsPtr + i * 8 + 4, true);
          let src, srcPos;
          if (fd === 0) {
            src = stdinBytes;
            srcPos = stdinPos;
          } else {
            const file = openFiles.get(fd);
            if (!file) return 8;
            src = file.data;
            srcPos = file.pos;
          }
          const n = Math.min(len, src.length - srcPos);
          buf.set(src.subarray(srcPos, srcPos + n), ptr);
          if (fd === 0) stdinPos += n;
          else openFiles.get(fd).pos += n;
          total += n;
          if (n < len) break;
        }
        dataView().setUint32(resultPtr, total, true);
        return 0;
      },
      fd_seek(fd, offset, whence, resultPtr) {
        const file = openFiles.get(fd);
        if (!file) return 8;
        const off = Number(offset);
        file.pos = whence === 0
          ? off
          : whence === 1
          ? file.pos + off
          : file.data.length + off;
        dataView().setBigUint64(resultPtr, BigInt(file.pos), true);
        return 0;
      },
      fd_write(fd, iovsPtr, iovsLen, resultPtr) {
        const view = dataView(),
          buf = bytes();
        let total = 0;
        for (let i = 0; i < iovsLen; i++) {
          const ptr = view.getUint32(iovsPtr + i * 8, true),
            len = view.getUint32(iovsPtr + i * 8 + 4, true);
          if (fd !== 1 && fd !== 2) return 8;
          if (stdoutLen + len > stdoutBuf.length) {
            const grown = new Uint8Array(stdoutBuf.length * 2);
            grown.set(stdoutBuf);
            stdoutBuf = grown;
          }
          stdoutBuf.set(buf.subarray(ptr, ptr + len), stdoutLen);
          stdoutLen += len;
          total += len;
        }
        dataView().setUint32(resultPtr, total, true);
        return 0;
      },
      fd_prestat_get(fd, resultPtr) {
        if (fd !== 3) return 8;
        const view = dataView();
        view.setUint32(resultPtr, 0, true);
        view.setUint32(resultPtr + 4, 1, true);
        return 0;
      },
      fd_prestat_dir_name(fd, ptr) {
        if (fd !== 3) return 8;
        bytes()[ptr] = 47;
        return 0;
      },
      path_open(_, __, pathPtr, pathLen, ___, ____, _____, ______, resultPtr) {
        const data = files.get(resolvePath(pathPtr, pathLen));
        if (!data) return 44;
        const fd = nextFd++;
        openFiles.set(fd, { data, pos: 0 });
        dataView().setUint32(resultPtr, fd, true);
        return 0;
      },
      path_filestat_get(_, __, pathPtr, pathLen, resultPtr) {
        const data = files.get(resolvePath(pathPtr, pathLen));
        if (!data) return 44;
        bytes().fill(0, resultPtr, resultPtr + 64);
        const view = dataView();
        view.setUint8(resultPtr + 16, 4);
        view.setBigUint64(resultPtr + 32, BigInt(data.length), true);
        return 0;
      },
      proc_exit(code) {
        throw new WasmExit(code);
      },
      random_get(ptr, len) {
        crypto.getRandomValues(new Uint8Array(memory.buffer, ptr, len));
        return 0;
      },
      sched_yield: stubOk,
      poll_oneoff: stubOk,
      proc_raise: stubNotSupported,
      sock_recv: stubNotSupported,
      sock_send: stubNotSupported,
      sock_shutdown: stubNotSupported,
      fd_advise: stubOk,
      fd_allocate: stubOk,
      fd_datasync: stubOk,
      fd_fdstat_set_flags: stubOk,
      fd_fdstat_set_rights: stubOk,
      fd_filestat_get() {
        return 8;
      },
      fd_filestat_set_size: stubOk,
      fd_filestat_set_times: stubOk,
      fd_pread: stubNotSupported,
      fd_pwrite: stubNotSupported,
      fd_readdir: stubNotSupported,
      fd_renumber: stubNotSupported,
      fd_sync: stubOk,
      fd_tell: stubNotSupported,
      path_create_directory: stubNotSupported,
      path_filestat_set_times: stubNotSupported,
      path_link: stubNotSupported,
      path_readlink: stubNotSupported,
      path_remove_directory: stubNotSupported,
      path_rename: stubNotSupported,
      path_symlink: stubNotSupported,
      path_unlink_file: stubNotSupported,
    },
  };
}

// --- WASM Execution ---

// Marks the start of the response payload in stdout — mirrors
// glowvm.sentinel in src/glowvm.gleam. A stray print in user code can only
// ever land before the last occurrence, so it can't corrupt the response.
const SENTINEL = "\n__GLOWVM__";

function runWasm(stdinJson, env) {
  const wasi = mkWasi(stdinJson, ["atomvm", "app.avm"], env);
  wasi.addFile("app.avm", getAvm());
  let memory;
  const instance = new WebAssembly.Instance(wasm, {
    wasi_snapshot_preview1: wasi.imports,
    env: envStubs,
  });
  memory = instance.exports.memory;
  wasi.setMem(instance.exports.memory);

  // _start has to be wrapped as "promising" for a call into it to be able
  // to suspend around host.call underneath — otherwise JSPI has nothing to
  // resume into and the suspending import just throws.
  const start = instance.exports._start;

  try {
    start();
  } catch (e) {
    if (e instanceof WasmExit) {
      if (e.code !== 0) {
        console.error(
          "WASM exit " + e.code + ": " + wasi.stdout().substring(0, 500),
        );
        throw new Error("runtime error");
      }
    } else {
      throw e;
    }
  }

  return parseOutput(wasi.stdout());
}

// AtomVM's runtime prints "Return value: <term>" to stdout after start/0
// returns, trailing after our JSON — so the sentinel only bounds the start;
// find the matching closing brace to bound the end too.
function parseOutput(out) {
  const start = out.lastIndexOf(SENTINEL);
  if (start < 0) return { error: "no output" };
  const i = start + SENTINEL.length;
  if (out[i] !== "{") return { error: "malformed output" };

  let depth = 0,
    inString = false,
    escaped = false,
    end = -1;
  for (let j = i; j < out.length; j++) {
    const c = out[j];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (c === "\\") {
      escaped = true;
      continue;
    }
    if (c === '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (c === "{") depth++;
    if (c === "}") {
      depth--;
      if (!depth) {
        end = j;
        break;
      }
    }
  }
  if (end < 0) return { error: "incomplete" };

  try {
    return JSON.parse(out.substring(i, end + 1));
  } catch {
    return { error: "malformed output" };
  }
}

// --- Worker Entry Point ---

const MAX_BODY_SIZE = 1024 * 1024; // 1 MB

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);

      // Extract headers
      const headers = {};
      request.headers.forEach((val, key) => {
        headers[key] = val;
      });

      // Read body with size limit
      let body = "";
      if (request.body) {
        const contentLength = request.headers.get("content-length");
        if (contentLength && parseInt(contentLength, 10) > MAX_BODY_SIZE) {
          return new Response(JSON.stringify({ error: "payload too large" }), {
            status: 413,
            headers: { "content-type": "application/json" },
          });
        }
        body = await request.text();
        if (encoder.encode(body).length > MAX_BODY_SIZE) {
          return new Response(JSON.stringify({ error: "payload too large" }), {
            status: 413,
            headers: { "content-type": "application/json" },
          });
        }
      }

      // Only string bindings make sense as WASI env vars — secrets,
      // KV/D1/service bindings etc. aren't strings and are skipped. Workers
      // pass vars via the `env` binding; other runtimes (Deno/Node, e.g.
      // the smoke tests) have no such binding, so fall back to process.env.
      const envSource = env ??
        (typeof process !== "undefined" ? process.env : {});
      const wasiEnv = {};
      for (const [key, val] of Object.entries(envSource ?? {})) {
        if (typeof val === "string") wasiEnv[key] = val;
      }

      const result = runWasm(
        JSON.stringify({
          method: request.method,
          url: url.pathname + url.search,
          headers,
          body,
        }),
        wasiEnv,
      );

      if (result.error) {
        return new Response(JSON.stringify(result), {
          status: 502,
          headers: { "content-type": "application/json" },
        });
      }

      const responseBody = result.encoding === "base64"
        ? Uint8Array.from(atob(result.body), (c) => c.charCodeAt(0))
        : result.body;

      return new Response(responseBody, {
        status: result.status,
        headers: result.headers,
      });
    } catch (e) {
      console.error("Worker error:", e.message || "unknown", e.stack || "");
      return new Response(JSON.stringify({ error: "internal server error" }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }
  },
};
