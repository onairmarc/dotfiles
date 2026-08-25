// provision/lib/state.ts
//
// Idempotency state management for the Bun provisioner.
// Loads and saves ~/.df_data/state.json using native JSON.
//
// State schema (schema_version 1):
// {
//   "schema_version": 1,
//   "tools_installed":   { "gh": true, ... },
//   "configurators_run": { "iterm": "2026-05-29T10:00:00Z" },
//   "migrations_run":    { "20250830_124338_setup_df_data_directory": "2026-05-29T..." }
// }
//
// Source-of-truth rules:
//   tools         — state is an optimization; live backend is always queried.
//   configurators — state IS the source of truth (one-shot, timestamp-only).
//   migrations    — state IS the source of truth.
//   scripts       — not tracked; always re-run.
import {readFileSync, writeFileSync} from "node:fs";
import * as platform from "./platform.ts";

export interface State {
    schema_version: number;
    tools_installed: Record<string, boolean | string>;
    configurators_run: Record<string, string>;
    migrations_run: Record<string, string>;
}

export type Category = "tools_installed" | "configurators_run" | "migrations_run";

const SCHEMA_VERSION = 1;

/** Build a blank state object with the correct schema. */
function blankState(): State {
    return {
        schema_version: SCHEMA_VERSION,
        tools_installed: {},
        configurators_run: {},
        migrations_run: {},
    };
}

/** Ensure the data directory exists. */
function ensureDataDir(): void {
    platform.mkdirP(platform.dataDir());
}

/**
 * Return an ISO 8601 UTC timestamp string for the current moment.
 * Date.toISOString() is always UTC, so the Windows local-time drift the Lua
 * version warned about does not apply here.
 */
function isoTimestamp(): string {
    return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

/** Return the full path to state.json. */
function statePath(): string {
    return platform.dataDir() + "/state.json";
}

/** Check whether a category entry has already been run. */
export function hasRun(s: State, category: Category, name: string): boolean {
    return s[category][name] !== undefined;
}

/** Persist state to disk. */
export function save(s: State): void {
    ensureDataDir();

    const path = statePath();
    const encoded = JSON.stringify({
        schema_version: s.schema_version ?? SCHEMA_VERSION,
        tools_installed: s.tools_installed ?? {},
        configurators_run: s.configurators_run ?? {},
        migrations_run: s.migrations_run ?? {},
    });
    try {
        writeFileSync(path, encoded);
    } catch (err) {
        throw new Error(
            "[state] Cannot write state.json: " + (err instanceof Error ? err.message : String(err)),
        );
    }
}

/**
 * Load state from disk.
 * Creates the data directory and an empty state.json if they do not exist.
 */
export function load(): State {
    ensureDataDir();

    const path = statePath();
    let content: string;
    try {
        content = readFileSync(path, "utf8");
    } catch {
        // First run: write the blank state immediately so it exists on disk.
        const initial = blankState();
        save(initial);

        return initial;
    }

    if (!content || content === "") {
        const initial = blankState();
        save(initial);

        return initial;
    }

    let decoded: unknown;
    try {
        decoded = JSON.parse(content);
    } catch {
        decoded = null;
    }

    if (!decoded || typeof decoded !== "object") {
        process.stderr.write("[state] WARNING: state.json is corrupt — resetting to blank state\n");

        const initial = blankState();
        save(initial);

        return initial;
    }

// Migrate missing keys (forward-compat for older files).
    const d = decoded as Partial<State>;

    return {
        schema_version: d.schema_version ?? SCHEMA_VERSION,
        tools_installed: d.tools_installed ?? {},
        configurators_run: d.configurators_run ?? {},
        migrations_run: d.migrations_run ?? {},
    };
}

/**
 * Mark a category entry as done in state.
 * tools_installed stores `true`; configurators_run and migrations_run store an
 * ISO timestamp.
 */
export function markDone(s: State, category: Category, name: string): void {
    if (category === "tools_installed") {
        s.tools_installed[name] = true;
    } else {
        s[category][name] = isoTimestamp();
    }
}