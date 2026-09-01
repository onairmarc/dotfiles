// tools/agent_symlink.ts
//
// Links repo files into OpenCode (and optional Claude) config paths.
//
// Every link this tool creates is write-through: the path a program opens
// (`linkPath`) is a symlink whose referent is the file or directory in this
// repo. Writes through the link mutate the repo file. Never copy, never
// hard-link, and never create a Windows junction.
import {lstatSync, mkdirSync, readFileSync, readdirSync, readlinkSync, renameSync, rmSync, symlinkSync, unlinkSync} from "node:fs";
import {dirname, isAbsolute, join, relative} from "node:path";

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

function findFiles(root: string): string[] {
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
            } else if (entry.isFile()) {
                out.push(path);
            }
        }
    };

    walk(root);

    return out;
}

function skillFrontmatterError(skillDir: string): string | null {
    const path = join(skillDir, "SKILL.md");
    let text: string;
    try {
        text = readFileSync(path, "utf8");
    } catch {
        return `${path}: missing SKILL.md`;
    }

    if (!text.startsWith("---")) {
        return `${path}: missing YAML frontmatter`;
    }

    const end = text.indexOf("\n---", 3);
    if (end === -1) {
        return `${path}: unclosed YAML frontmatter`;
    }

    let data: unknown;
    try {
        data = Bun.YAML.parse(text.slice(4, end));
    } catch (error) {
        return `${path}: invalid YAML frontmatter (${error instanceof Error ? error.message : String(error)})`;
    }

    if (data === null || typeof data !== "object" || Array.isArray(data)) {
        return `${path}: frontmatter must be a mapping`;
    }

    const fields = data as Record<string, unknown>;
    if (typeof fields.name !== "string" || fields.name.trim() === "") {
        return `${path}: missing name`;
    }

    if (typeof fields.description !== "string" || fields.description.trim() === "") {
        return `${path}: missing description`;
    }

    return null;
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

function resolveReferent(referent: string, linkPath: string): string {
    if (isAbsolute(referent)) {
        return referent;
    }

    return join(dirname(linkPath), referent);
}

function writeThroughType(referent: string, linkPath: string): "dir" | "file" | undefined {
    if (process.platform !== "win32") {
        return undefined;
    }

    try {
        return lstatSync(resolveReferent(referent, linkPath)).isDirectory() ? "dir" : "file";
    } catch {
        return "file";
    }
}

function alreadyWriteThrough(linkPath: string, referent: string): boolean {
    try {
        return lstatSync(linkPath).isSymbolicLink() && readlinkSync(linkPath) === referent;
    } catch {
        return false;
    }
}

function createWriteThroughLink(referent: string, linkPath: string): void {
    symlinkSync(referent, linkPath, writeThroughType(referent, linkPath));
}

function linkWriteThrough(referent: string, linkPath: string, label: string): void {
    if (!exists(resolveReferent(referent, linkPath))) {
        logWarn(`Source does not exist, skipping: ${referent}`);

        return;
    }

    mkdirSync(dirname(linkPath), {recursive: true});
    if (alreadyWriteThrough(linkPath, referent)) {
        logInfo(`${label}: ${linkPath} already write-through -> ${referent}`);

        return;
    }

    logInfo(`${label}: ${linkPath} -> ${referent}`);
    if (exists(linkPath)) {
        logInfo(`  Removing existing: ${linkPath}`);
        rmSync(linkPath, {recursive: true, force: true});
    }

    createWriteThroughLink(referent, linkPath);
    logInfo(`  Created write-through symlink: ${linkPath} -> ${referent}`);
}

function linkGlobalFile(referent: string, linkPath: string, label: string): void {
    if (!exists(resolveReferent(referent, linkPath))) {
        logWarn(`Source does not exist, skipping: ${referent}`);

        return;
    }

    mkdirSync(dirname(linkPath), {recursive: true});
    if (alreadyWriteThrough(linkPath, referent)) {
        logInfo(`${label}: ${linkPath} already write-through -> ${referent}`);

        return;
    }

    if (exists(linkPath)) {
        const stat = lstatSync(linkPath);
        if (stat.isSymbolicLink()) {
            unlinkSync(linkPath);
        } else if (stat.isFile()) {
            logInfo(`${label}: backing up existing ${linkPath} to ${linkPath}.bak`);
            renameSync(linkPath, linkPath + ".bak");
        }
    }

    createWriteThroughLink(referent, linkPath);
    logInfo(`${label}: ${linkPath} -> ${referent}`);
}

function privateSkillsSource(privateDir: string): string {
    const agentsSkills = join(privateDir, "agents", "skills");
    if (isDir(agentsSkills)) {
        return agentsSkills;
    }

    return join(privateDir, ".agents", "skills");
}

let debugMode = false;

function logDebug(msg: string): void {
    if (debugMode) {
        process.stdout.write(`${GREEN}[DEBUG]${NC} ${msg}\n`);
    }
}

function linkSkillsFlat(sourceRoot: string, label: string, targets: string[]): string[] {
    const prefix = label !== "" ? `${label} ` : "";
    const errors: string[] = [];

    for (const skillPath of findSkillDirs(sourceRoot)) {
        const skillName = skillPath.split(/[/\\]/).pop() ?? skillPath;
        const frontmatterError = skillFrontmatterError(skillPath);
        if (frontmatterError !== null) {
            errors.push(frontmatterError);
            logWarn(`  ${frontmatterError}`);
        }

        for (const targetDir of targets) {
            const dest = join(targetDir, skillName);
            if (exists(dest)) {
                logWarn(`  Skill collision on '${skillName}' in ${targetDir}: ${label || "later"} wins, overriding earlier`);
                rmSync(dest, {recursive: true, force: true});
            }

            createWriteThroughLink(skillPath, dest);
            logDebug(`  Linked ${prefix}skill: ${skillName} -> ${targetDir}`);
        }

        logInfo(`  Linked ${prefix}skill: ${skillName}`);
    }

    return errors;
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
): string[] {
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

        return [
            ...linkSkillsFlat(publicSource, "public", targets),
            ...linkSkillsFlat(privateSource, "private", targets),
        ];
    }

    logInfo(`${label}: linking public skills into ${targets.join(" ")}`);

    if (privateDir !== "") {
        logDebug(`  (no private dotfiles found at ${privateDir})`);
    }

    return linkSkillsFlat(publicSource, "", targets);
}

function finishSync(skillErrors: string[]): void {
    if (skillErrors.length > 0) {
        logError(`${skillErrors.length} skill(s) have invalid SKILL.md frontmatter`);
        process.exit(1);
    }

    logInfo("Sync complete!");
}

export function syncGlobalOpencode(): void {
    const dotfilesRoot = dirname(import.meta.dir);
    const skillsSource = join(dotfilesRoot, "agents", "skills");
    if (!isDir(skillsSource)) {
        throw new Error(`Source directory does not exist: ${skillsSource}`);
    }

    const privateDir = process.env.DF_PRIVATE_DIRECTORY
        || join(homeDir(), "Documents", "GitHub", "dotfiles-private");
    const privateSkills = privateSkillsSource(privateDir);
    const configDir = join(homeDir(), ".config", "opencode");
    const skillErrors = populateSkillsTargets(
        skillsSource,
        privateSkills,
        privateDir,
        "Global mode",
        [join(configDir, "skills")],
    );

    if (skillErrors.length > 0) {
        throw new Error(`${skillErrors.length} skill(s) have invalid SKILL.md frontmatter`);
    }

    const pluginsSource = join(dotfilesRoot, "opencode", "plugins");
    linkGlobalFile(join(dotfilesRoot, "agents", "AGENTS.md"), join(configDir, "AGENTS.md"), "Global mode");
    linkGlobalFile(join(dotfilesRoot, "opencode", "opencode.jsonc"), join(configDir, "opencode.jsonc"), "Global mode");
    linkGlobalFile(join(dotfilesRoot, "opencode", "tui.jsonc"), join(configDir, "tui.jsonc"), "Global mode");
    for (const file of findFiles(pluginsSource)) {
        linkGlobalFile(file, join(configDir, relative(pluginsSource, file)), "Global mode");
    }

    logInfo("Sync complete!");
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
        syncGlobalOpencode();

        if (claudeMode) {
            const skillsSource = join(repoRoot, "agents", "skills");
            const privateDir = process.env.DF_PRIVATE_DIRECTORY
                || join(homeDir(), "Documents", "GitHub", "dotfiles-private");
            const privateSkills = privateSkillsSource(privateDir);
            const skillErrors = populateSkillsTargets(
                skillsSource,
                privateSkills,
                privateDir,
                "Claude global mode",
                [join(homeDir(), ".claude", "skills")],
            );
            linkWriteThrough(join(repoRoot, "agents", "AGENTS.md"), join(homeDir(), ".claude", "CLAUDE.md"), "Global mode");
            finishSync(skillErrors);
        }

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

            createWriteThroughLink("AGENTS.md", claudeFile);
            logInfo(`  Created write-through symlink: ${claudeFile} -> AGENTS.md`);
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

    let skillErrors: string[] = [];
    if (!isDir(localSkillsSource)) {
        logWarn(`Skipping skills: source does not exist (${localSkillsSource})`);
    } else {
        skillErrors = populateSkillsTargets(localSkillsSource, "", "", "In-repo mode", localSkillTargets);
    }

    if (claudeMode) {
        const claudeMdTarget = join(repoRoot, "CLAUDE.md");
        const agentsMdSource = join(repoRoot, "AGENTS.md");
        if (!exists(agentsMdSource)) {
            logWarn("Skipping CLAUDE.md: source does not exist (AGENTS.md)");
        } else {
            linkWriteThrough("AGENTS.md", claudeMdTarget, "In-repo mode");
        }
    }

    finishSync(skillErrors);
}

if (import.meta.main) {
    main(process.argv.slice(2));
}
