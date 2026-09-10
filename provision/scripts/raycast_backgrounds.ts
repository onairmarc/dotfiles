import {join} from "node:path";
import {dotfilesRoot} from "../lib/platform.ts";
import {run, runAssert} from "../lib/shell.ts";

if (process.platform !== "darwin") {
    throw new Error("The Raycast backgrounds extension requires macOS");
}

const node = run(["node", "-p", "process.versions.node"]);
const [major, minor] = node.stdout.trim().split(".").map(Number);
if (!node.ok || !(major > 22 || (major === 22 && minor >= 14))) {
    throw new Error("Node.js 22.14 or later must be on PATH to install the Raycast backgrounds extension");
}

runAssert(
    ["/usr/bin/open", "-g", "-b", "com.raycast.macos"],
    "Raycast must be installed before installing the backgrounds extension",
);

const directory = join(dotfilesRoot(), "raycast", "desktop-background");
for (const args of [["install", "--frozen-lockfile"], ["run", "install-local"]]) {
    const result = run([process.execPath, ...args], {cwd: directory});
    process.stdout.write(result.stdout);
    process.stderr.write(result.stderr);
    if (!result.ok) {
        throw new Error(`Raycast backgrounds installation failed: bun ${args.join(" ")}`);
    }
}
