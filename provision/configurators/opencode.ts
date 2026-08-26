// provision/configurators/opencode.ts
//
// Symlinks the repo OpenCode config into ~/.config/opencode/.
//
// Logic (all native node:fs — no shell):
//   1. Create ~/.config/opencode/ if missing.
//   2. For opencode.json and tui.json: if a real file exists, rename it to *.bak.
//   3. If the path is not already a symlink to the repo file, create the symlink.
import {lstatSync, mkdirSync, readlinkSync, renameSync, symlinkSync, unlinkSync} from "node:fs";
import * as log from "../lib/log.ts";
import * as platform from "../lib/platform.ts";

/** lstat without throwing — returns null when the path does not exist. */
function lstatOrNull(path: string): ReturnType<typeof lstatSync> | null {
    try {
        return lstatSync(path);
    } catch {
        return null;
    }
}

function linkFile(src: string, dest: string): void {
    const stat = lstatOrNull(dest);
    if (stat && stat.isSymbolicLink()) {
        if (readlinkSync(dest) === src) {
            log.info("opencode", dest + " already linked — skipping");

            return;
        }

        unlinkSync(dest);
    } else if (stat && stat.isFile()) {
        log.info("opencode", "backing up existing " + dest + " to " + dest + ".bak");
        renameSync(dest, dest + ".bak");
    }

    symlinkSync(src, dest);
    log.info("opencode", dest + " symlinked");
}

export function run(): void {
    const home = platform.home();
    const dfRoot = platform.dotfilesRoot();
    const configDir = home + "/.config/opencode";
    mkdirSync(configDir, {recursive: true});
    linkFile(dfRoot + "/opencode/opencode.json", configDir + "/opencode.json");
    linkFile(dfRoot + "/opencode/tui.json", configDir + "/tui.json");
}