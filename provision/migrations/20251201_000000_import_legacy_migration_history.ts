// provision/migrations/20251201_000000_import_legacy_migration_history.ts
//
// Migration: import legacy shell-runner migration history into Bun state.
//
// The old bash-based migration runner tracked completed migrations in a flat
// text file (one migration name per line). This migration reads both the
// public and private history files and imports each entry into the provisioner
// state.migrations_run map so the runner never re-runs them.
//
// Public entries  → state.migrations_run["<name>"] = "imported"
// Private entries → state.migrations_run["private:<name>"] = "imported"
//
// Both legacy files are left in place as audit trails; the runner ignores them
// going forward.
//
// The migrations runner passes the live state object as the first argument to
// up(); writing directly into it ensures the entries survive the runner's own
// save(s) call after this function returns.
import {readFileSync} from "node:fs";
import type {Migration} from "../lib/migrations.ts";
import type {State} from "../lib/state.ts";

const migration: Migration = {
    name: "20251201_000000_import_legacy_migration_history",
    description: "Import legacy bash migration history into Bun provisioner state",
    up(s: State) {
        const home = process.env.HOME || process.env.USERPROFILE || "";
        const dfRoot = process.env.DF_ROOT_DIRECTORY || home + "/Documents/GitHub/dotfiles";

        // Helper: read a history file and import entries with an optional prefix.
        const importHistory = (path: string, prefix: string) => {
            let content: string;
            try {
                content = readFileSync(path, "utf8");
            } catch {
                return; // file absent — nothing to import
            }

            for (const rawLine of content.split(/\r?\n/)) {
                const line = rawLine.trim();
                if (line !== "") {
                    const key = prefix + line;

                    // Only set if not already recorded (preserve existing timestamps).
                    if (s.migrations_run[key] === undefined) {
                        s.migrations_run[key] = "imported";
                    }
                }
            }
        };

        // Public dotfiles history.
        importHistory(dfRoot + "/migrations/.migration_history", "");

        // Private dotfiles history (optional — may not exist on all machines).
        const privateRoot = home + "/Documents/GitHub/dotfiles-private";
        importHistory(privateRoot + "/.migrations/.migration_history", "private:");
    },
};

export default migration;