// provision/lib/backend.ts
//
// Package manager backends for the Bun provisioner.
// Supported backends: brew (formula), cask (Homebrew cask), choco (Chocolatey).
//
// Every operation spawns the package manager directly by argv and inspects its
// output in TypeScript — no shell, no piping to grep/findstr. This is both
// portable (works identically without cmd.exe on Windows) and easier to reason
// about than the original shell one-liners.
//
// Each backend exposes:
//   isInstalled(id, opts) -> boolean
//   install(id, opts)     -> void  (throws on failure)
//
// opts fields (all optional):
//   tap  string  Homebrew tap to add before installing (brew/cask only).
//   app  string  Absolute path to a .app bundle; if the path exists the tool is
//                considered installed (cask only, mirrors install.sh:15).

import { existsSync } from "node:fs";
import { run, runAssert } from "./shell.ts";

export interface BackendOpts {
  tap?: string;
  app?: string;
}

export interface Backend {
  isInstalled(id: string, opts?: BackendOpts): boolean;
  install(id: string, opts?: BackendOpts): void;
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
  return m ? `${m[1]}/${m[2]}` : null;
}

/** Split command output into a trimmed, non-empty line list. */
function lines(text: string): string[] {
  return text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l !== "");
}

/**
 * Trust a Homebrew tap (Homebrew 6+ tap-trust).
 * Official taps are always trusted (brew prints a no-op). Soft-fails on older
 * Homebrew without `brew trust` so provision still works.
 */
function trustTap(tap: string): void {
  if (!tap || tap === "") {
    return;
  }
  run(["brew", "trust", "--tap", tap]); // best-effort; ignore result
}

/** Ensure a tap is present and trusted before install. */
function ensureTap(tap: string): void {
  if (!tap || tap === "") {
    return;
  }
  runAssert(["brew", "tap", tap], "brew tap failed: " + tap);
  trustTap(tap);
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
    const { ok, stdout } = run(["brew", "tap"]);
    if (!ok) {
      return;
    }
    for (const tap of lines(stdout)) {
      if (tap.startsWith("homebrew/")) {
        continue;
      }
      trustTap(tap);
    }
  },

  /**
   * Check whether a Homebrew formula is installed.
   * Matches the exact package name against `brew list --formula`. For
   * tap-qualified IDs both the full form and the bare formula name are tried
   * because `brew list` reports the bare name only.
   */
  isInstalled(id: string, _opts?: BackendOpts): boolean {
    const { ok, stdout } = run(["brew", "list", "--formula"]);
    if (!ok) {
      return false;
    }
    const installed = new Set(lines(stdout));
    if (installed.has(id)) {
      return true;
    }
    const bare = id.split("/").pop();
    return bare !== undefined && bare !== id && installed.has(bare);
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
    runAssert(["brew", "install", id], "brew install failed: " + id);
  },
} satisfies Backend & { trustInstalledTaps(): void };

// ---------------------------------------------------------------------------
// cask (Homebrew cask)
// ---------------------------------------------------------------------------

export const cask = {
  /**
   * Check whether a Homebrew cask is installed.
   * If opts.app is provided and the path exists, returns true immediately
   * (mirrors install.sh:15 `[ -d "$app_path" ]`). Otherwise queries
   * `brew list --cask`.
   */
  isInstalled(id: string, opts?: BackendOpts): boolean {
    if (opts?.app && opts.app !== "" && existsSync(opts.app)) {
      return true;
    }
    const { ok, stdout } = run(["brew", "list", "--cask"]);
    return ok && new Set(lines(stdout)).has(id);
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
    runAssert(["brew", "install", "--cask", id], "brew install --cask failed: " + id);
  },
} satisfies Backend;

// ---------------------------------------------------------------------------
// choco (Chocolatey — Windows)
// ---------------------------------------------------------------------------

export const choco = {
  /**
   * Check whether a Chocolatey package is installed.
   * `choco list <id> --exact --limit-output` prints "<id>|<version>" when found;
   * the id is matched case-insensitively against the first field of each line.
   */
  isInstalled(id: string, _opts?: BackendOpts): boolean {
    const { ok, stdout } = run(["choco", "list", id, "--exact", "--limit-output"]);
    if (!ok) {
      return false;
    }
    const target = id.toLowerCase();
    return lines(stdout).some((l) => l.split("|")[0].toLowerCase() === target);
  },

  /** Install a Chocolatey package. */
  install(id: string, _opts?: BackendOpts): void {
    runAssert(["choco", "install", id, "-y"], "choco install failed: " + id);
  },
} satisfies Backend;

const BACKENDS: Record<string, Backend> = { brew, cask, choco };

/** Resolve a backend by name string. */
export function get(name: string): Backend {
  const b = BACKENDS[name];
  if (!b) {
    throw new Error("Unknown backend: " + String(name));
  }
  return b;
}
