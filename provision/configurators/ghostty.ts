// provision/configurators/ghostty.ts
//
// Configures Ghostty terminal by symlinking the dotfiles config file.
// Replicates install.sh:47-66 (configure_ghostty function).
//
// Logic:
//   1. Create ~/.config/ghostty/ if missing.
//   2. If a real file (not a symlink) exists at ~/.config/ghostty/config,
//      rename it to config.bak.
//   3. If the symlink does not exist yet, create it pointing to
//      $DF_ROOT_DIRECTORY/ghostty/config.
import * as log from "../lib/log.ts";
import * as platform from "../lib/platform.ts";
import {shellExec, shellOk, shq} from "../lib/shell.ts";

export function run(): void {
    const home = process.env.HOME || "";
    const dfRoot = platform.dotfilesRoot();
    const configDir = home + "/.config/ghostty";
    const configLink = configDir + "/config";
    const configSrc = dfRoot + "/ghostty/config";

// 1. Ensure config directory exists.
    shellExec(`mkdir -p ${shq(configDir)}`);

// 2. If a real file exists (not a symlink), back it up.
//    test -f is true for regular files; test -L is true for symlinks.
//    We want: regular file exists AND is NOT a symlink → back up.
    if (shellOk(`test -f ${shq(configLink)} && ! test -L ${shq(configLink)}`)) {
        log.info("ghostty", "backing up existing config to config.bak");
        shellExec(`mv ${shq(configLink)} ${shq(configDir + "/config.bak")}`);
    }

// 3. Create symlink if not already present.
    if (shellOk(`test -L ${shq(configLink)}`)) {
        log.info("ghostty", "config symlink already exists — skipping");
    } else {
        shellExec(`ln -s ${shq(configSrc)} ${shq(configLink)}`);
        log.info("ghostty", "config symlinked");
    }
}