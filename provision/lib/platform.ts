// provision/lib/platform.ts
//
// Platform detection and helpers for the Bun provisioner.
// Platform is read from the first CLI argument passed to main.ts ("mac" or
// "windows"/"win"). Any other value causes an immediate error exit.
import {mkdirSync} from "node:fs";
import {homedir} from "node:os";

export type Platform = "mac" | "windows";

// Resolved platform, set by init().
let _platform: Platform | null = null;

// Allowlist of recognized platform strings → canonical name.
const PLATFORM_ALIASES: Record<string, Platform> = {
    mac: "mac",
    windows: "windows",
    win: "windows",
};

/** Return the canonical platform name ("mac" or "windows"). */
export function current(): Platform {
    if (!_platform) {
        throw new Error("platform.init() has not been called");
    }

    return _platform;
}

/**
 * Return the user home directory.
 * Uses $HOME on mac/linux-style systems; $USERPROFILE on Windows.
 */
export function home(): string {
    return process.env.HOME || process.env.USERPROFILE || homedir() || "";
}

/** Return the data directory used for state persistence (~/.df_data). */
export function dataDir(): string {
    return `${home()}/.df_data`;
}

/**
 * Return the dotfiles root directory.
 * Honors $DF_ROOT_DIRECTORY if set; otherwise defaults to
 * $HOME/Documents/GitHub/dotfiles.
 */
export function dotfilesRoot(): string {
    return process.env.DF_ROOT_DIRECTORY || `${home()}/Documents/GitHub/dotfiles`;
}

/**
 * Initialize platform from the CLI argument.
 * Must be called once at startup (main.ts). Exits with an error message if
 * the platform argument is missing or not in the allowlist.
 */
export function init(argPlatform: string | undefined): void {
    if (!argPlatform || argPlatform === "") {
        process.stderr.write("[platform] ERROR: platform argument is required (mac | windows)\n");
        process.exit(2);
    }

    const canonical = PLATFORM_ALIASES[argPlatform.toLowerCase()];
    if (!canonical) {
        process.stderr.write(
            `[platform] ERROR: unsupported platform "${argPlatform}" — must be one of: mac, windows\n`,
        );

        process.exit(2);
    }

    _platform = canonical;
}

/** Return true when running on macOS. */
export function isMac(): boolean {
    return current() === "mac";
}

/** Return true when running on Windows. */
export function isWindows(): boolean {
    return current() === "windows";
}

/**
 * Return true if an entry's platform list includes the current platform.
 * If entry.platforms is nil or empty, the entry applies to all platforms.
 */
export function matches(entry: { platforms?: string[] }): boolean {
    if (!entry.platforms || entry.platforms.length === 0) {
        return true;
    }

    const cur = current();
    return entry.platforms.some((p) => PLATFORM_ALIASES[p.toLowerCase()] === cur);
}

/**
 * Create a directory (and any missing parents) idempotently.
 * Native recursive mkdir — no shell involved, so it is portable across
 * mac and Windows without the `mkdir -p` / literal `-p` directory pitfall.
 */
export function mkdirP(path: string): void {
    mkdirSync(path, {recursive: true});
}