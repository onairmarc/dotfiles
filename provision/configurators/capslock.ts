// provision/configurators/capslock.ts
//
// Remaps Caps Lock to Escape via the dedicated shell tool.
// Delegates to tools/remap_capslock.sh --enable (kept as a shell tool because
// it uses hidutil(1) which is macOS-only and simpler in bash).
import * as platform from "../lib/platform.ts";
import {shellOk, shq} from "../lib/shell.ts";

export function run(): void {
    const dfRoot = platform.dotfilesRoot();
    const script = dfRoot + "/tools/remap_capslock.sh";
    const cmd = `bash ${shq(script)} --enable`;
    if (!shellOk(cmd)) {
        throw new Error("remap_capslock.sh --enable failed");
    }
}