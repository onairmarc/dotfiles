// Links repo files into OpenCode and optional Claude config paths.
//
// Links are write-through. The OpenCode custom plugin is copied because
// OpenCode requires a real plugin directory.
import {lstatSync, mkdirSync, readFileSync, renameSync, rmSync, unlinkSync} from "node:fs";
import {dirname, join, relative} from "node:path";
import {
    alreadyWriteThrough,
    copyDirectory,
    createWriteThroughLink,
    exists,
    findDirectoriesContaining,
    findFiles,
    findFilesNamed,
    gitTopLevel,
    homeDirectory,
    isDirectory,
} from "./lib.ts";

const GREEN = "\x1b[0;32m";
const NC = "\x1b[0m";
const YELLOW = "\x1b[1;33m";
const RED = "\x1b[0;31m";
const USAGE = "Usage: agent_symlink [--global] [--claude] [-r] [--debug]";

type Options = {
    claude: boolean;
    global: boolean;
    recursive: boolean;
};

function logInfo(message: string): void {
    process.stdout.write(`${GREEN}[INFO]${NC} ${message}\n`);
}

function removeManagedLink(source: string, target: string, label: string): void {
    if (alreadyWriteThrough(target, source)) {
        unlinkSync(target);
        logInfo(`${label}: removed managed link ${target}`);
    }
}

function cleanupGlobalConfigLinks(dotfilesRoot: string, configDir: string): void {
    removeManagedLink(join(dotfilesRoot, "opencode", "opencode.jsonc"), join(configDir, "opencode.jsonc"), "Global mode");
    removeManagedLink(join(dotfilesRoot, "opencode", "global", "tui.jsonc"), join(configDir, "tui.jsonc"), "Global mode");
}

function cleanupMisplacedCustomPluginLinks(configDir: string, pluginsSource: string, customPluginSource: string): void {
    for (const file of findFiles(customPluginSource)) {
        removeManagedLink(file, join(configDir, relative(pluginsSource, file)), "Global mode");
    }
}

function cleanupRetiredGlobalLinks(configDir: string, agentsSource: string, pluginsSource: string): void {
    removeManagedLink(join(agentsSource, "the-implementor.md"), join(configDir, "agents", "the-implementor.md"), "Global mode");

    for (const agent of ["implementor.md", "orchestrator.md"]) {
        removeManagedLink(join(agentsSource, agent), join(configDir, "agents", agent), "Global mode");
    }

    for (const command of ["feature-planning.md", "plan-execute.md", "plan-resync.md", "plan-review.md", "plan-split.md"]) {
        removeManagedLink(join(pluginsSource, "..", "commands", command), join(configDir, "commands", command), "Global mode");
    }

    removeManagedLink(join(pluginsSource, "skill-command-router.ts"), join(configDir, "skill-command-router.ts"), "Global mode");
    removeManagedLink(join(pluginsSource, "skill-command-router.ts"), join(configDir, "plugins", "skill-command-router.ts"), "Global mode");
}

function logWarn(message: string): void {
    process.stdout.write(`${YELLOW}[WARN]${NC} ${message}\n`);
}

function copyPlugin(source: string, target: string, label: string): void {
    if (!exists(source)) {
        logWarn(`Source does not exist, skipping: ${source}`);

        return;
    }

    mkdirSync(dirname(target), {recursive: true});

    if (exists(target)) {
        rmSync(target, {recursive: true, force: true});
    }

    copyDirectory(source, target);
    logInfo(`${label}: copied plugin ${source} -> ${target}`);
}

function logError(message: string): void {
    process.stderr.write(`${RED}[ERROR]${NC} ${message}\n`);
}

function finishSync(skillErrors: string[]): void {
    if (skillErrors.length > 0) {
        logError(`${skillErrors.length} skill(s) have invalid SKILL.md frontmatter`);
        process.exit(1);
    }

    logInfo("Sync complete!");
}

function linkGlobalFile(referent: string, linkPath: string, label: string): void {
    if (!exists(referent)) {
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

    return typeof fields.description === "string" && fields.description.trim() !== ""
        ? null
        : `${path}: missing description`;
}

let debugMode = false;

function logDebug(message: string): void {
    if (debugMode) {
        process.stdout.write(`${GREEN}[DEBUG]${NC} ${message}\n`);
    }
}

function linkSkills(sourceRoot: string, label: string, targets: string[]): string[] {
    const prefix = label === "" ? "" : `${label} `;
    const errors: string[] = [];

    for (const skillPath of findDirectoriesContaining(sourceRoot, "SKILL.md")) {
        const skillName = skillPath.split(/[/\\]/).pop() ?? skillPath;
        const frontmatterError = skillFrontmatterError(skillPath);
        if (frontmatterError !== null) {
            errors.push(frontmatterError);
            logWarn(`  ${frontmatterError}`);
        }

        for (const targetDir of targets) {
            const target = join(targetDir, skillName);
            if (exists(target)) {
                logWarn(`  Skill collision on '${skillName}' in ${targetDir}: ${label || "later"} wins, overriding earlier`);
                rmSync(target, {recursive: true, force: true});
            }

            createWriteThroughLink(skillPath, target);
            logDebug(`  Linked ${prefix}skill: ${skillName} -> ${targetDir}`);
        }

        logInfo(`  Linked ${prefix}skill: ${skillName}`);
    }

    return errors;
}

function linkWriteThrough(referent: string, linkPath: string, label: string): void {
    if (!exists(join(dirname(linkPath), referent))) {
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

function parseOptions(args: string[]): Options {
    const options: Options = {claude: false, global: false, recursive: false};

    for (const arg of args) {
        switch (arg) {
            case "--global":
                options.global = true;
                break;
            case "--claude":
                options.claude = true;
                break;
            case "-r":
            case "--recursive":
                options.recursive = true;
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

    if (options.global && options.recursive) {
        logError("--global and -r cannot be used together");
        process.stdout.write(`${USAGE}\n`);
        process.exit(1);
    }

    if (options.recursive && !options.claude) {
        logError("-r/--recursive is Claude-specific; pass --claude");
        process.stdout.write(`${USAGE}\n`);
        process.exit(1);
    }

    return options;
}

function populateSkillsTargets(
    publicSource: string,
    privateSource: string,
    privateDir: string,
    label: string,
    targets: string[],
): string[] {
    for (const target of targets) {
        if (exists(target)) {
            logDebug(`  Removing existing: ${target}`);
            rmSync(target, {recursive: true, force: true});
        }

        mkdirSync(target, {recursive: true});
    }

    if (privateSource !== "" && isDirectory(privateSource)) {
        logInfo(`${label}: interleaving public + private skills into ${targets.join(" ")}`);
        logDebug(`  Public:  ${publicSource}`);
        logDebug(`  Private: ${privateSource}`);

        return [
            ...linkSkills(publicSource, "public", targets),
            ...linkSkills(privateSource, "private", targets),
        ];
    }

    logInfo(`${label}: linking public skills into ${targets.join(" ")}`);

    if (privateDir !== "") {
        logDebug(`  (no private dotfiles found at ${privateDir})`);
    }

    return linkSkills(publicSource, "", targets);
}

function privateSkillsSource(privateDir: string): string {
    const agentsSkills = join(privateDir, "agents", "skills");
    return isDirectory(agentsSkills) ? agentsSkills : join(privateDir, ".agents", "skills");
}

export function syncGlobalOpencode(): void {
    const dotfilesRoot = dirname(import.meta.dir);
    const configDir = join(homeDirectory(), ".config", "opencode");
    const skillsSource = join(dotfilesRoot, "agents", "skills");
    if (!isDirectory(skillsSource)) {
        throw new Error(`Source directory does not exist: ${skillsSource}`);
    }

    const privateDir = process.env.DF_PRIVATE_DIRECTORY || join(homeDirectory(), "Documents", "GitHub", "dotfiles-private");
    const skillErrors = populateSkillsTargets(
        skillsSource,
        privateSkillsSource(privateDir),
        privateDir,
        "Global mode",
        [join(configDir, "skills")],
    );

    if (skillErrors.length > 0) {
        throw new Error(`${skillErrors.length} skill(s) have invalid SKILL.md frontmatter`);
    }

    const pluginsSource = join(dotfilesRoot, "opencode", "plugins");
    const customPluginSource = join(pluginsSource, "custom");
    const agentsSource = join(dotfilesRoot, "opencode", "agents");

    linkGlobalFile(join(dotfilesRoot, "agents", "AGENTS.md"), join(configDir, "AGENTS.md"), "Global mode");
    cleanupGlobalConfigLinks(dotfilesRoot, configDir);
    cleanupRetiredGlobalLinks(configDir, agentsSource, pluginsSource);
    cleanupMisplacedCustomPluginLinks(configDir, pluginsSource, customPluginSource);

    for (const file of findFiles(agentsSource)) {
        linkGlobalFile(file, join(configDir, "agents", relative(agentsSource, file)), "Global mode");
    }

    copyPlugin(customPluginSource, join(configDir, "plugins", "custom"), "Global mode");

    for (const file of findFiles(pluginsSource)) {
        const isCustomPluginFile = !relative(customPluginSource, file).startsWith("..") && !relative(customPluginSource, file).startsWith("/");
        if (!isCustomPluginFile) {
            const target = file.endsWith(".ts") || file.endsWith(".js")
                ? join(configDir, "plugins", relative(pluginsSource, file))
                : join(configDir, relative(pluginsSource, file));
            linkGlobalFile(file, target, "Global mode");
        }
    }

    logInfo("Sync complete!");
}

function syncGlobalClaude(repoRoot: string): void {
    const privateDir = process.env.DF_PRIVATE_DIRECTORY || join(homeDirectory(), "Documents", "GitHub", "dotfiles-private");
    const skillErrors = populateSkillsTargets(
        join(repoRoot, "agents", "skills"),
        privateSkillsSource(privateDir),
        privateDir,
        "Claude global mode",
        [join(homeDirectory(), ".claude", "skills")],
    );

    linkWriteThrough("AGENTS.md", join(homeDirectory(), ".claude", "CLAUDE.md"), "Global mode");
    finishSync(skillErrors);
}

function syncRecursiveClaude(cwd: string): void {
    logInfo(`Recursive mode: scanning for AGENTS.md files under ${cwd}`);

    let created = 0;
    let skipped = 0;

    for (const agentsFile of findFilesNamed(cwd, "AGENTS.md")) {
        const claudeFile = join(dirname(agentsFile), "CLAUDE.md");
        if (exists(claudeFile)) {
            logWarn(`  Skipping ${claudeFile}: already exists`);
            skipped += 1;
            continue;
        }

        createWriteThroughLink("AGENTS.md", claudeFile);
        logInfo(`  Created write-through symlink: ${claudeFile} -> AGENTS.md`);
        created += 1;
    }

    logInfo(`Sync complete! Created ${created} symlink(s), skipped ${skipped}.`);
}

function syncLocal(repoRoot: string, claude: boolean): void {
    const skillsSource = join(repoRoot, "agents", "skills");
    const targets = [join(repoRoot, ".opencode", "skills")];

    if (claude) {
        targets.push(join(repoRoot, ".claude", "skills"));
    }

    const skillErrors = isDirectory(skillsSource)
        ? populateSkillsTargets(skillsSource, "", "", "In-repo mode", targets)
        : [];

    if (!isDirectory(skillsSource)) {
        logWarn(`Skipping skills: source does not exist (${skillsSource})`);
    }

    if (claude) {
        const source = join(repoRoot, "AGENTS.md");
        if (!exists(source)) {
            logWarn("Skipping CLAUDE.md: source does not exist (AGENTS.md)");
        } else {
            linkWriteThrough("AGENTS.md", join(repoRoot, "CLAUDE.md"), "In-repo mode");
        }
    }

    finishSync(skillErrors);
}

function main(args: string[]): void {
    const options = parseOptions(args);
    const dotfilesRoot = dirname(import.meta.dir);

    if (options.global) {
        syncGlobalOpencode();

        if (options.claude) {
            syncGlobalClaude(dotfilesRoot);
        }

        return;
    }

    const repoRoot = gitTopLevel(process.cwd());
    if (repoRoot === null) {
        logError("Not in a git repository. Please run this script from within a git repo.");
        process.exit(1);
    }

    if (options.recursive) {
        syncRecursiveClaude(process.cwd());

        return;
    }

    syncLocal(repoRoot, options.claude);
}

if (import.meta.main) {
    main(process.argv.slice(2));
}