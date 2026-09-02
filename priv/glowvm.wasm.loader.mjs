import { readFileSync } from "node:fs";
const bytes = readFileSync(new URL("./glowvm.wasm", import.meta.url));
export default await WebAssembly.compile(bytes);
