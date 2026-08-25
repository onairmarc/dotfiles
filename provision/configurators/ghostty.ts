// provision/configurators/ghostty.ts
//
// Configures Ghostty terminal by symlinking the dotfiles config file.
// Replicates install.sh:47-66 (configure_ghostty function).
//
// Logic (all native node:fs — no shell):
//   1. Create ~/.config/ghostty/ if missing.
//   2. If a real file (not a symlink) exists at ~/.config/ghostty/config, rename
//      it to config.bak.
//   3. If the symlink does not exist yet, create it pointing to
//      $DF_ROOT_DIRECTORY/ghostty/config.
import {lstatSync, mkdirSync, renameSync, symlinkSync} from "node:fs";
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

export function run(): void {
    const home = process.env.HOME || "";
    const dfRoot = platform.dotfilesRoot();
    const configDir = home + "/.config/ghostty";
    const configLink = configDir + "/config";
    const configSrc = dfRoot + "/ghostty/config";

// 1. Ensure config directory exists.
    mkdirSync(configDir, {recursive: true});

    const stat = lstatOrNull(configLink);

// 2. If a real regular file exists (not a symlink), back it up.
    if (stat && stat.isFile() && !stat.isSymbolicLink()) {
        log.info("ghostty", "backing up existing config to config.bak");
        renameSync(configLink, configDir + "/config.bak");
    }

// 3. Create symlink if not already present.
    if (stat && stat.isSymbolicLink()) {
        log.info("ghostty", "config symlink already exists — skipping");
    } else {
        symlinkSync(configSrc, configLink);
        log.info("ghostty", "config symlinked");
    }
}