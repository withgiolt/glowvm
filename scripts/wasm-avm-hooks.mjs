// Node module customization hooks (module.register API) teaching Node how
// to resolve `import wasm from "./glowvm.wasm"` and `import avm from
// "./app.avm"` — workerd-only import sugar that Node has no native
// equivalent for. Mirrors what workerd actually hands index.js: a compiled
// WebAssembly.Module for .wasm, raw bytes for .avm.
//
// Hooks run in a separate loader thread/realm and can't share closures
// with the registering module, so the "source" returned for each format is
// synthetic ESM text — it reads its own file back via import.meta.url
// (which Node sets to the resolved .wasm/.avm URL) rather than us reading
// the bytes here and trying to smuggle a live object across the boundary.

const WASM_SOURCE = `
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
const bytes = readFileSync(fileURLToPath(import.meta.url));
export default await WebAssembly.compile(bytes);
`;

const AVM_SOURCE = `
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
export default readFileSync(fileURLToPath(import.meta.url));
`;

export async function resolve(specifier, context, nextResolve) {
  if (specifier.endsWith(".wasm") || specifier.endsWith(".avm")) {
    return {
      url: new URL(specifier, context.parentURL).href,
      shortCircuit: true,
    };
  }
  return nextResolve(specifier, context);
}

export async function load(url, context, nextLoad) {
  if (url.endsWith(".wasm")) {
    return { format: "module", source: WASM_SOURCE, shortCircuit: true };
  }
  if (url.endsWith(".avm")) {
    return { format: "module", source: AVM_SOURCE, shortCircuit: true };
  }
  return nextLoad(url, context);
}
