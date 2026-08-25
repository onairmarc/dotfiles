// provision/lib/backend.ts
//
// Package manager backends for the Bun provisioner.
// Supported backends: brew (formula), cask (Homebrew cask), choco (Chocolatey).
//
// Each backend exposes:
//   isInstalled(id, opts) -> boolean
//   install(id, opts)     -> void  (throws on failure)
//
// opts fields (all optional):
//   tap  string  Homebrew tap to add before installing (brew/cask only).
//   app  string  Absolute path to a .app bundle; if the path exists the tool
//                is considered installed (cask only, mirrors install.sh:15).
import {shellAssert, shellOk, shq} from "./shell.ts";

export interface BackendOpts {
    tap?: string;
    app?: string;
}

export interface Backend {
    isInstalled(id: string, opts?: BackendOpts): boolean;

    install(id: string, opts?: BackendOpts): void;
}

/**
 * Trust a Homebrew tap (Homebrew 6+ tap-trust).
 * Official taps are always trusted (brew prints a no-op message). Soft-fails
 * on older Homebrew without `brew trust` so provision still works.
 */
function trustTap(tap: string): void {
    if (!tap || tap === "") {
        return;
    }

    shellOk(`brew trust --tap ${shq(tap)} >/dev/null 2>&1`);
}

/** Ensure a tap is present and trusted before install. */
function ensureTap(tap: string): void {
    if (!tap || tap === "") {
        return;
    }

    shellAssert(`brew tap ${shq(tap)}`, "brew tap failed: " + tap);
    trustTap(tap);
}

/**
 * Extract a tap name from a tap-qualified package id.
 * "hashicorp/tap/terraform" → "hashicorp/tap"; "gh" → null.
 */
function tapFromId(id: string): string | null {
    if (!id || id === "") {
        return null;
    }

    const m = id.match(/^([^/]+)\/([^/]+)\//);
    if (m) {
        return `${m[1]}/${m[2]}`;
    }

    return null;
}

// ---------------------------------------------------------------------------
// brew (Homebrew formula)
// ---------------------------------------------------------------------------
export const brew = {
    /**
     * Trust every installed third-party tap (Homebrew 6+).
     * Official homebrew/* taps are skipped. Soft-fails if `brew trust` is missing.
     * Call once at the start of the tools phase so already-tapped repos stop
     * emitting "Skipping … because it is not trusted" during brew operations.
     */
    trustInstalledTaps(): void {
        shellOk(`
      brew tap 2>/dev/null | while IFS= read -r tap; do
        [ -n "$tap" ] || continue
        case "$tap" in
          homebrew/*) continue ;;
          *) brew trust --tap "$tap" >/dev/null 2>&1 || true ;;
        esac
      done
    `);
    },
    /**
     * Check whether a Homebrew formula is installed.
     * Queries `brew list --formula` and matches the exact package name. For
     * tap-qualified IDs both the full form and the bare formula name are tried
     * because `brew list` reports the bare name only.
     */
    isInstalled(id: string, _opts?: BackendOpts): boolean {
        if (shellOk(`brew list --formula 2>/dev/null | grep -qx ${shq(id)}`)) {
            return true;
        }

        const bare = id.match(/[^/]+$/)?.[0];
        if (bare && bare !== id) {
            return shellOk(`brew list --formula 2>/dev/null | grep -qx ${shq(bare)}`);
        }

        return false;
    },
    /**
     * Install a Homebrew formula.
     * Taps and trusts opts.tap (or the tap embedded in a qualified id) first.
     */
    install(id: string, opts?: BackendOpts): void {
        const tap = opts?.tap ?? tapFromId(id);
        if (tap) {
            ensureTap(tap);
        }

        shellAssert(`brew install ${shq(id)}`, "brew install failed: " + id);
    },
} satisfies Backend & { trustInstalledTaps(): void };

// ---------------------------------------------------------------------------
// cask (Homebrew cask)
// ---------------------------------------------------------------------------
export const cask = {
    /**
     * Check whether a Homebrew cask is installed.
     * If opts.app is provided and the path exists as a directory, returns true
     * immediately (mirrors install.sh:15 `[ -d "$app_path" ]` check). Otherwise
     * queries `brew list --cask`.
     */
    isInstalled(id: string, opts?: BackendOpts): boolean {
        if (opts?.app && opts.app !== "") {
            if (shellOk(`test -d ${shq(opts.app)}`)) {
                return true;
            }
        }

        return shellOk(`brew list --cask 2>/dev/null | grep -qx ${shq(id)}`);
    },
    /**
     * Install a Homebrew cask.
     * Taps and trusts opts.tap (or the tap embedded in a qualified id) first.
     */
    install(id: string, opts?: BackendOpts): void {
        const tap = opts?.tap ?? tapFromId(id);
        if (tap) {
            ensureTap(tap);
        }

        shellAssert(`brew install --cask ${shq(id)}`, "brew install --cask failed: " + id);
    },
} satisfies Backend;

// ---------------------------------------------------------------------------
// choco (Chocolatey — Windows)
// ---------------------------------------------------------------------------
export const choco = {
    /**
     * Check whether a Chocolatey package is installed.
     * Uses `choco list <id> --exact --limit-output` (Chocolatey v2 syntax). The
     * command exits 0 and prints "<id>|<version>" when the package is found.
     */
    isInstalled(id: string, _opts?: BackendOpts): boolean {
        // cmd.exe syntax: choco output is piped to findstr; exit 0 = found.
        const cmd = `choco list "${id}" --exact --limit-output 2>nul | findstr /i "${id}" >nul 2>&1`;
        return shellOk(cmd);
    },
    /** Install a Chocolatey package. */
    install(id: string, _opts?: BackendOpts): void {
        shellAssert(`choco install "${id}" -y`, "choco install failed: " + id);
    },
} satisfies Backend;

const BACKENDS: Record<string, Backend> = {brew, cask, choco};

/** Resolve a backend by name string. */
export function get(name: string): Backend {
    const b = BACKENDS[name];
    if (!b) {
        throw new Error("Unknown backend: " + String(name));
    }

    return b;
}