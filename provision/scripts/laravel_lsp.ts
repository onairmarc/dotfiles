import {run, runAssert} from "../lib/shell.ts";

const herd = run(["herd", "list"]);
if (!herd.ok) {
    throw new Error("Laravel Herd is required to install laravel/lsp");
}

runAssert(["herd", "composer", "global", "require", "laravel/lsp"]);
