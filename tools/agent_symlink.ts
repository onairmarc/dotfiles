import {lstatSync, mkdirSync, readdirSync, rmSync, symlinkSync} from "node:fs";
import {dirname, join} from "node:path";

function exists(path: string): boolean {
    try {
        lstatSync(path);

        return true;
    } catch {
        return false;
    }
}

function findNamedFiles(root: string, name: string): string[] {
    const out: string[] = [];
    const walk = (dir: string): void => {
        let entries;
        try {
            entries = readdirSync(dir, {withFileTypes: true});
        } catch {
            return;
        }

        for (const entry of entries) {
            const path = join(dir, entry.name);

            if (entry.isDirectory()) {
                walk(path);
            } else if (entry.isFile() && entry.name === name) {
                out.push(path);
            }
        }
    };

    walk(root);

    return out;
}

function findSkillDirs(root: string): string[] {
    const out: string[] = [];
    const walk = (dir: string): void => {
        let entries;
        try {
            entries = readdirSync(dir, {withFileTypes: true});
        } catch {
            return;
        }

        for (const entry of entries) {
            const path = join(dir, entry.name);

            if (entry.isDirectory()) {
                walk(path);
            } else if (entry.isFile() && entry.name === "SKILL.md") {
                out.push(dir);
            }
        }
    };

    walk(root);

    return out;
}

function gitTopLevel(cwd: string): string | null {
    const r = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"], {
        cwd,
        stdout: "pipe",
        stderr: "pipe",
    });

    if (r.exitCode !== 0) {
        return null;
    }

    return r.stdout.toString().trim();
}

function homeDir(): string {
    return process.env.HOME || process.env.USERPROFILE || "";
}

function isDir(path: string): boolean {
    try {
        return lstatSync(path).isDirectory();
    } catch {
        return false;
    }
}

const YELLOW = "\x1b[1;33m";

const NC = "\x1b[0m";

function logWarn(msg: string): void {
    process.stdout.write(`${YELLOW}[WARN]${NC} ${msg}\n`);
}

const GREEN = "\x1b[0;32m";

function logInfo(msg: string): void {
    process.stdout.write(`${GREEN}[INFO]${NC} ${msg}\n`);
}

function symlink(target: string, path: string): void {
    let type: "dir" | "file" | undefined;

    if (process.platform === "win32") {
        try {
            type = lstatSync(target).isDirectory() ? "dir" : "file";
        } catch {
            type = "file";
        }
    }

    symlinkSync(target, path, type);
}

function linkFile(source: string, target: string, label: string): void {
    if (!exists(source)) {
        logWarn(`Source does not exist, skipping: ${source}`);

        return;
    }

    mkdirSync(dirname(target), {recursive: true});
    logInfo(`${label}: ${target} -> ${source}`);

    if (exists(target)) {
        logInfo(`  Removing existing: ${target}`);
        rmSync(target, {force: true});
    }

    symlink(source, target);
    logInfo(`  Created symlink: ${target} -> ${source}`);
}

let debugMode = false;

function logDebug(msg: string): void {
    if (debugMode) {
        process.stdout.write(`${GREEN}[DEBUG]${NC} ${msg}\n`);
    }
}

function linkSkillsFlat(sourceRoot: string, label: string, targets: string[]): void {
    const prefix = label !== "" ? `${label} ` : "";

    for (const skillPath of findSkillDirs(sourceRoot)) {
        const skillName = skillPath.split(/[/\\]/).pop() ?? skillPath;

        for (const targetDir of targets) {
            const dest = join(targetDir, skillName);
            if (exists(dest)) {
                logWarn(`  Skill collision on '${skillName}' in ${targetDir}: ${label || "later"} wins, overriding earlier`);
                rmSync(dest, {recursive: true, force: true});
            }

            symlink(skillPath, dest);
            logDebug(`  Linked ${prefix}skill: ${skillName} -> ${targetDir}`);
        }

        logInfo(`  Linked ${prefix}skill: ${skillName}`);
    }
}

const RED = "\x1b[0;31m";

function logError(msg: string): void {
    process.stderr.write(`${RED}[ERROR]${NC} ${msg}\n`);
}

const USAGE = "Usage: agent_symlink [--global] [--claude] [-r] [--debug]";

function populateSkillsTargets(
    publicSource: string,
    privateSource: string,
    privateDir: string,
    label: string,
    targets: string[],
): void {
    for (const targetDir of targets) {
        if (exists(targetDir)) {
            logDebug(`  Removing existing: ${targetDir}`);
            rmSync(targetDir, {recursive: true, force: true});
        }

        mkdirSync(targetDir, {recursive: true});
    }

    if (privateSource !== "" && isDir(privateSource)) {
        logInfo(`${label}: interleaving public + private skills into ${targets.join(" ")}`);
        logDebug(`  Public:  ${publicSource}`);
        logDebug(`  Private: ${privateSource}`);
        linkSkillsFlat(publicSource, "public", targets);
        linkSkillsFlat(privateSource, "private", targets);

        return;
    }

    logInfo(`${label}: linking public skills into ${targets.join(" ")}`);

    if (privateDir !== "") {
        logDebug(`  (no private dotfiles found at ${privateDir})`);
    }

    linkSkillsFlat(publicSource, "", targets);
}

function main(argv: string[]): void {
    let globalMode = false;
    let claudeMode = false;
    let recursiveMode = false;

    for (const arg of argv) {
        switch (arg) {
            case "--global":
                globalMode = true;
                break;
            case "--claude":
                claudeMode = true;
                break;
            case "-r":
            case "--recursive":
                recursiveMode = true;
                break;
            case "--debug":
                debugMode = true;
                break;
            default:
                logError(`Unknown option: ${arg}`);
                process.stdout.write(`${USAGE}\n`);
                process.exit(1);
        }
    }

    if (globalMode && recursiveMode) {
        logError("--global and -r cannot be used together");
        process.stdout.write(`${USAGE}\n`);
        process.exit(1);
    }

    if (recursiveMode && !claudeMode) {
        logError("-r/--recursive is Claude-specific; pass --claude");
        process.stdout.write(`${USAGE}\n`);
        process.exit(1);
    }

    const dotfilesRoot = dirname(import.meta.dir);
    let repoRoot: string;

    if (globalMode) {
        repoRoot = dotfilesRoot;
    } else {
        const top = gitTopLevel(process.cwd());
        if (!top) {
            logError("Not in a git repository. Please run this script from within a git repo.");
            process.exit(1);
        }

        repoRoot = top;
    }

    if (globalMode) {
        const skillsSource = join(repoRoot, "agents", "skills");
        if (!isDir(skillsSource)) {
            logError(`Source directory does not exist: ${skillsSource}`);
            process.exit(1);
        }

        const privateDir = process.env.DF_PRIVATE_DIRECTORY
            || join(homeDir(), "Documents", "GitHub", "dotfiles-private");

        const privateSkillsSource = join(privateDir, "agents", "skills");
        const skillTargets = [join(homeDir(), ".config", "opencode", "skills")];

        if (claudeMode) {
            mkdirSync(join(homeDir(), ".claude"), {recursive: true});
            skillTargets.push(join(homeDir(), ".claude", "skills"));
        }

        populateSkillsTargets(skillsSource, privateSkillsSource, privateDir, "Global mode", skillTargets);
        linkFile(join(repoRoot, "agents", "AGENTS.md"), join(homeDir(), ".config", "opencode", "AGENTS.md"), "Global mode");
        linkFile(join(repoRoot, "opencode", "opencode.json"), join(homeDir(), ".config", "opencode", "opencode.json"), "Global mode");
        linkFile(join(repoRoot, "opencode", "tui.json"), join(homeDir(), ".config", "opencode", "tui.json"), "Global mode");

        if (claudeMode) {
            linkFile(join(repoRoot, "agents", "AGENTS.md"), join(homeDir(), ".claude", "CLAUDE.md"), "Global mode");
        }

        logInfo("Sync complete!");

        return;
    }

    if (recursiveMode) {
        const cwd = process.cwd();
        logInfo(`Recursive mode: scanning for AGENTS.md files under ${cwd}`);

        let found = 0;
        let skipped = 0;

        for (const agentsFile of findNamedFiles(cwd, "AGENTS.md")) {
            const dir = dirname(agentsFile);
            const claudeFile = join(dir, "CLAUDE.md");
            if (exists(claudeFile)) {
                logWarn(`  Skipping ${claudeFile}: already exists`);
                skipped += 1;
                continue;
            }

            symlink("AGENTS.md", claudeFile);
            logInfo(`  Created symlink: ${claudeFile} -> AGENTS.md`);
            found += 1;
        }

        logInfo(`Sync complete! Created ${found} symlink(s), skipped ${skipped}.`);

        return;
    }

    const localSkillsSource = join(repoRoot, "agents", "skills");
    const localSkillTargets = [join(repoRoot, ".opencode", "skills")];

    if (claudeMode) {
        localSkillTargets.push(join(repoRoot, ".claude", "skills"));
    }

    if (!isDir(localSkillsSource)) {
        logWarn(`Skipping skills: source does not exist (${localSkillsSource})`);
    } else {
        populateSkillsTargets(localSkillsSource, "", "", "In-repo mode", localSkillTargets);
    }

    if (claudeMode) {
        const claudeMdTarget = join(repoRoot, "CLAUDE.md");
        const agentsMdSource = join(repoRoot, "AGENTS.md");
        if (!exists(agentsMdSource)) {
            logWarn("Skipping CLAUDE.md: source does not exist (AGENTS.md)");
        } else {
            logInfo(`Creating symlink: ${claudeMdTarget} -> AGENTS.md`);

            if (exists(claudeMdTarget)) {
                logInfo(`  Removing existing: ${claudeMdTarget}`);
                rmSync(claudeMdTarget, {recursive: true, force: true});
            }

            symlink("AGENTS.md", claudeMdTarget);
            logInfo("  Created symlink");
        }
    }

    logInfo("Sync complete!");
}

if (import.meta.main) {
    main(process.argv.slice(2));
}