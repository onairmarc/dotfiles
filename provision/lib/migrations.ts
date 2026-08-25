// provision/lib/migrations.ts
//
// Ordered migration runner for the Bun provisioner.
// Migrations are discovered from manifest.migrations (an ordered list of
// migration objects). Each migration exposes:
//   { name, description?, up(state) }
//
// State key conventions:
//   Public migrations  → bare name (e.g. "20250830_124338_setup_df_data_directory")
//   Private migrations → recorded with a "private:" prefix, applied by the
//                        legacy-history-import migration, not by this runner.
//
// On failure, execution STOPS (unlike tools/scripts/configurators which continue).
import * as log from "./log.ts";
import * as stateMod from "./state.ts";
import type {State} from "./state.ts";

export interface Migration {
    name: string;
    description?: string;
    up: (s: State) => void;
}

/**
 * Run all pending migrations listed in manifest.migrations.
 * Stops on the first failure.
 * @returns [true] on full success; [false, message] on failure.
 */
export function runPending(s: State, migrationList: Migration[]): [boolean, string?] {
    if (!migrationList || migrationList.length === 0) {
        log.info("migrations", "nothing to run");

        return [true];
    }

    for (const migration of migrationList) {
        const name = migration.name;
        if (stateMod.hasRun(s, "migrations_run", name)) {
            log.ok(name, "already run — skipping");
            continue;
        }

        log.info(name, "running migration…");

        if (typeof migration.up !== "function") {
            const msg = `migration ${name} must expose an up() function`;
            log.error(name, msg);

            return [false, msg];
        }
        try {
            // Pass the live state object so migrations that modify migrations_run
            // directly (e.g. the legacy-history importer) write into the same object
            // the runner will stamp and save.
            migration.up(s);
        } catch (err) {
            const msg = `migration ${name} failed: ${err instanceof Error ? err.message : String(err)}`;
            log.error(name, msg);

            return [false, msg];
        }

        // Stamp success.
        stateMod.markDone(s, "migrations_run", name);
        stateMod.save(s);
        log.ok(name, "migration complete");
    }

    return [true];
}