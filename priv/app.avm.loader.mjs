import { readFileSync } from "node:fs";
export default readFileSync(new URL("./app.avm", import.meta.url));
