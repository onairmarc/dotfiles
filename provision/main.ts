// provision/main.ts
//
// Entrypoint for the Bun provisioner.
//
// Usage:
//   bun provision/main.ts <platform> [mode-flag]
//
//   platform : mac | windows | win
//   mode-flag: --tools-only | --scripts-only | --configurators-only | --migrate
//              (default: run tools, scripts, configurators, then migrations)
//
// Exit codes:
//   0  all steps succeeded (or nothing to do)
//   1  one or more steps failed
//   2  bad arguments / unsupported platform
import * as backend from "./lib/backend.ts";
import * as log from "./lib/log.ts";
import * as migrations from "./lib/migrations.ts";
import * as platform from "./lib/platform.ts";
import * as scripts from "./lib/scripts.ts";
import * as stateMod from "./lib/state.ts";
import manifest from "./manifest.ts";

// ---------------------------------------------------------------------------
// Failure accumulator
// ---------------------------------------------------------------------------
interface Failure {
    name: string;
    msg: string;
}

function errMsg(err: unknown): string {
    return err instanceof Error ? err.message : String(err);
}

const failures: Failure[] = [];

function recordFailure(name: string, msg: string): void {
    log.error(name, msg);
    failures.push({name, msg});
}

// ---------------------------------------------------------------------------
// Counters for the summary table
// ---------------------------------------------------------------------------
const counts = {
    tools_installed: 0,
    tools_skipped: 0,
    tools_failed: 0,
    scripts_run: 0,
    scripts_skipped: 0,
    scripts_failed: 0,
    configs_run: 0,
    configs_skipped: 0,
    configs_failed: 0,
    migrations_run: 0,
    migrations_skip: 0,
    migrations_fail: 0,
};

let RUN_CONFIGURATORS = true;
let RUN_MIGRATIONS = true;
let RUN_SCRIPTS = true;

// Parse mode flag.
let RUN_TOOLS = true;

// ---------------------------------------------------------------------------
// Load state
// ---------------------------------------------------------------------------
const state = stateMod.load();

// ---------------------------------------------------------------------------
// Parse arguments
// ---------------------------------------------------------------------------
const [platformArg, modeArg] = process.argv.slice(2);

// Initialize and validate platform (exits on invalid input).
platform.init(platformArg);

if (modeArg) {
    RUN_TOOLS = modeArg === "--tools-only";
    RUN_SCRIPTS = modeArg === "--scripts-only";
    RUN_CONFIGURATORS = modeArg === "--configurators-only";
    RUN_MIGRATIONS = modeArg === "--migrate";

    if (
        modeArg !== "--tools-only"
        && modeArg !== "--scripts-only"
        && modeArg !== "--configurators-only"
        && modeArg !== "--migrate"
    ) {
        process.stderr.write("[main] ERROR: unknown mode flag: " + modeArg + "\n");
        process.stderr.write(
            "       Valid flags: --tools-only | --scripts-only | --configurators-only | --migrate\n",
        );

        process.exit(2);
    }
}

// ---------------------------------------------------------------------------
// Tools
// ---------------------------------------------------------------------------
if (RUN_TOOLS) {
    log.step("Installing tools");

// Map canonical platform name to the manifest sub-object key.
    const platKey = platform.current() === "windows" ? "win" : "mac";

// Homebrew 6+ requires third-party taps to be explicitly trusted; otherwise
// brew skips them with "Skipping … because it is not trusted". Trust every
// already-installed third-party tap before any brew list/install work.
    if (platKey === "mac") {
        log.info("brew", "trusting third-party taps…");
        backend.brew.trustInstalledTaps();
        log.ok("brew", "third-party taps trusted");
    }

    for (const entry of manifest.tools) {
        const pentry = entry[platKey];
        if (!pentry) continue;
        const name = entry.name || pentry.id || "unknown";
        const id = pentry.id;
        const b = backend.get(pentry.backend);
        const opts = {tap: pentry.tap, app: pentry.app};
        let installed: boolean;
        try {
            installed = b.isInstalled(id, opts);
        } catch (err) {
            recordFailure(name, "isInstalled check error: " + errMsg(err));
            counts.tools_failed += 1;
            continue;
        }

        if (installed) {
            log.ok(name, "already installed — skipping");
            counts.tools_skipped += 1;
            stateMod.markDone(state, "tools_installed", name);
        } else {
            log.info(name, "installing…");
            try {
                b.install(id, opts);
                log.ok(name, "installed");
                counts.tools_installed += 1;
                stateMod.markDone(state, "tools_installed", name);
            } catch (err) {
                recordFailure(name, "install failed: " + errMsg(err));
                counts.tools_failed += 1;
            }
        }
    }

    stateMod.save(state);
}

// ---------------------------------------------------------------------------
// Scripts
// ---------------------------------------------------------------------------
if (RUN_SCRIPTS) {
    log.step("Running scripts");

    const platKeyS = platform.current() === "windows" ? "win" : "mac";

    for (const entry of manifest.scripts) {
        const pentry = entry[platKeyS];
        if (!pentry) continue;
        const label = entry.name || pentry.url || pentry.kind || "unknown";
        const [skip, skipReason] = scripts.shouldSkip(pentry);
        if (skip) {
            log.ok(label, "skipped — " + (skipReason || "condition met"));
            counts.scripts_skipped += 1;
        } else {
            log.info(label, "running…");
            try {
                scripts.run(pentry);
                log.ok(label, "done");
                counts.scripts_run += 1;
            } catch (err) {
                recordFailure(label, errMsg(err));
                counts.scripts_failed += 1;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Configurators
// ---------------------------------------------------------------------------
if (RUN_CONFIGURATORS) {
    log.step("Running configurators");

    for (const entry of manifest.configurators) {
        if (!platform.matches(entry)) continue;
        const name = entry.name || "unknown";
        if (stateMod.hasRun(state, "configurators_run", name)) {
            log.ok(name, "already configured — skipping");
            counts.configs_skipped += 1;
            continue;
        }

        log.info(name, "configuring…");
        try {
            if (typeof entry.run !== "function") {
                throw new Error("configurator must expose a run() function");
            }

            entry.run();
            stateMod.markDone(state, "configurators_run", name);
            stateMod.save(state);
            log.ok(name, "configured");
            counts.configs_run += 1;
        } catch (err) {
            recordFailure(name, errMsg(err));
            counts.configs_failed += 1;
        }
    }
}

// ---------------------------------------------------------------------------
// Migrations
// ---------------------------------------------------------------------------
if (RUN_MIGRATIONS) {
    log.step("Running migrations");

    const [migOk, migErr] = migrations.runPending(state, manifest.migrations);
    if (!migOk) {
        recordFailure("migrations", migErr || "migration run failed");
        counts.migrations_fail = 1;
    }

// Save state after migrations (runPending already saves on each success;
// this is a belt-and-suspenders final save).
    stateMod.save(state);
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
process.stdout.write("\n");
log.step("Summary");
process.stdout.write(
    `  Tools      : ${counts.tools_installed} installed, ${counts.tools_skipped} skipped, ${counts.tools_failed} failed\n`,
);

process.stdout.write(
    `  Scripts    : ${counts.scripts_run} run, ${counts.scripts_skipped} skipped, ${counts.scripts_failed} failed\n`,
);

process.stdout.write(
    `  Configurators: ${counts.configs_run} run, ${counts.configs_skipped} skipped, ${counts.configs_failed} failed\n`,
);

process.stdout.write(
    `  Migrations : ${counts.migrations_run} run, ${counts.migrations_skip} skipped, ${counts.migrations_fail} failed\n`,
);

if (failures.length > 0) {
    process.stdout.write("\n");
    log.warn("failures", String(failures.length) + " failure(s) during this run:");
    failures.forEach((f, i) => {
        process.stderr.write(`    [${i + 1}] ${f.name}: ${f.msg}\n`);
    });

    process.exit(1);
}

process.exit(0);