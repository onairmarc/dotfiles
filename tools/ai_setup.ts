// Installs third-party skills and synchronizes global OpenCode configuration.
import {lstatSync, mkdirSync, readFileSync, renameSync, rmSync, unlinkSync} from "node:fs";
import {basename, dirname, join, relative} from "node:path";
import {
    alreadyWriteThrough,
    createWriteThroughLink,
    exists,
    findDirectoriesContaining,
    findFiles,
    homeDirectory,
    isDirectory,
} from "./lib.ts";

const GREEN = "\x1b[0;32m";
const NC = "\x1b[0m";
const RED = "\x1b[0;31m";
const YELLOW = "\x1b[1;33m";
const USAGE = "Usage: ai_setup [--sync] [--reinstall] [--debug]";

const SKILLS = [
    {repository: "mattpocock/skills", skill: "*"},
    {repository: "vercel-labs/agent-skills", skill: "vercel-react-best-practices"},
    {repository: "JuliusBrussee/caveman", skill: "*"},
];

type Options = {
    debug: boolean;
    reinstall: boolean;
    sync: boolean;
};

function fail(message: string): never {
    process.stderr.write(`${RED}[ERROR]${NC} ${message}\n${USAGE}\n`);
    process.exit(1);
}

function logInfo(message: string): void {
    process.stdout.write(`${GREEN}[INFO]${NC} ${message}\n`);
}

function logWarn(message: string): void {
    process.stdout.write(`${YELLOW}[WARN]${NC} ${message}\n`);
}

function run(command: string[]): void {
    const result = Bun.spawnSync(command, {stdin: "inherit", stdout: "inherit", stderr: "inherit"});
    if (result.exitCode !== 0) {
        throw new Error(`command failed: ${command.join(" ")}`);
    }
}

function installSkills(): void {
    for (const {repository, skill} of SKILLS) {
        run(["bunx", "skills@latest", "add", repository, "--global", "--skill", skill, "--agent", "opencode", "-y"]);
    }
}

function removeSkills(): void {
    try {
        run(["bunx", "skills@latest", "remove", "--global", "--skill", "*", "--agent", "opencode", "-y"]);
    } catch {
        // The remove command is best effort so a first installation still succeeds.
    }
}

function parseOptions(args: string[]): Options {
    const options: Options = {debug: false, reinstall: false, sync: false};

    for (const arg of args) {
        switch (arg) {
            case "--debug":
                options.debug = true;
                break;
            case "--reinstall":
                options.reinstall = true;
                break;
            case "--sync":
                options.sync = true;
                break;
            case "-h":
            case "--help":
                process.stdout.write(`${USAGE}\n`);
                process.exit(0);
            default:
                fail(`unknown option: ${arg}`);
        }
    }

    if (options.sync && options.reinstall) {
        fail("--reinstall cannot be used with --sync");
    }

    return options;
}

function removeManagedLink(source: string, target: string, label: string): void {
    if (alreadyWriteThrough(target, source)) {
        unlinkSync(target);
    }
}

function cleanupRetiredGlobalConfigLinks(dotfilesRoot: string, configDir: string): void {
    removeManagedLink(join(dotfilesRoot, "opencode", "tui.jsonc"), join(configDir, "tui.jsonc"), "Global mode");
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

function cleanupRetiredGlobalSkills(configDir: string): void {
    const skillsDir = join(configDir, "skills");
    if (exists(skillsDir)) {
        rmSync(skillsDir, {recursive: true, force: true});
        logInfo(`Global mode: removed retired skills directory ${skillsDir}`);
    }
}

function linkGlobalFile(referent: string, linkPath: string, label: string, debug: boolean): void {
    if (!exists(referent)) {
        logWarn(`Source does not exist, skipping: ${referent}`);

        return;
    }

    mkdirSync(dirname(linkPath), {recursive: true});

    if (alreadyWriteThrough(linkPath, referent)) {
        if (debug) {
            logInfo(`${label}: already synced ${basename(linkPath)}`);
        }

        return;
    }

    if (exists(linkPath)) {
        const stat = lstatSync(linkPath);
        if (stat.isSymbolicLink()) {
            unlinkSync(linkPath);
        } else if (stat.isFile()) {
            logInfo(`${label}: backed up ${basename(linkPath)}`);
            renameSync(linkPath, linkPath + ".bak");
        }
    }

    createWriteThroughLink(referent, linkPath);
    logInfo(`${label}: synced ${basename(linkPath)}`);
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

function linkSkills(sourceRoot: string, label: string, targetDir: string, debug: boolean): string[] {
    const errors: string[] = [];

    for (const skillPath of findDirectoriesContaining(sourceRoot, "SKILL.md")) {
        const skillName = skillPath.split(/[/\\]/).pop() ?? skillPath;
        const frontmatterError = skillFrontmatterError(skillPath);
        if (frontmatterError !== null) {
            errors.push(frontmatterError);
            logWarn(`  ${frontmatterError}`);
        }

        const target = join(targetDir, skillName);
        if (alreadyWriteThrough(target, skillPath)) {
            if (debug) {
                logInfo(`  ${label} skill already linked: ${skillName}`);
            }

            continue;
        }

        if (exists(target)) {
            logWarn(`  Skill collision on '${skillName}' in ${targetDir}: ${label} wins, overriding earlier`);
            rmSync(target, {recursive: true, force: true});
        }

        createWriteThroughLink(skillPath, target);
        if (debug) {
            logInfo(`  Linked ${label} skill: ${skillName} -> ${targetDir}`);
        } else {
            logInfo(`  Linked ${label} skill: ${skillName}`);
        }
    }

    return errors;
}

function privateSkillsSource(privateDir: string): string {
    const agentsSkills = join(privateDir, "agents", "skills");
    return isDirectory(agentsSkills) ? agentsSkills : join(privateDir, ".agents", "skills");
}

function syncGlobalSkills(dotfilesRoot: string, debug: boolean): string[] {
    const publicSource = join(dotfilesRoot, "agents", "skills");
    if (!isDirectory(publicSource)) {
        throw new Error(`Source directory does not exist: ${publicSource}`);
    }

    const target = join(homeDirectory(), ".agents", "skills");
    mkdirSync(target, {recursive: true});

    const privateDir = process.env.DF_PRIVATE_DIRECTORY || join(homeDirectory(), "Documents", "GitHub", "dotfiles-private");
    const privateSource = privateSkillsSource(privateDir);
    logInfo("Global mode: syncing public skills");
    const errors = linkSkills(publicSource, "public", target, debug);

    if (isDirectory(privateSource)) {
        logInfo("Global mode: syncing private skills");
        errors.push(...linkSkills(privateSource, "private", target, debug));
    } else if (debug) {
        logInfo(`Global mode: no private skills found at ${privateDir}`);
    }

    return errors;
}

export function syncGlobalOpencode(debug = false): void {
    const dotfilesRoot = dirname(import.meta.dir);
    const configDir = join(homeDirectory(), ".config", "opencode");
    const skillErrors = syncGlobalSkills(dotfilesRoot, debug);
    const pluginsSource = join(dotfilesRoot, "opencode", "plugins");
    const configFile = join(dotfilesRoot, "opencode", "opencode.json");
    const cliConfigFile = join(dotfilesRoot, "opencode", "cli.json");
    const agentsSource = join(dotfilesRoot, "opencode", "agents");

    cleanupRetiredGlobalConfigLinks(dotfilesRoot, configDir);
    cleanupRetiredGlobalSkills(configDir);
    cleanupRetiredGlobalLinks(configDir, agentsSource, pluginsSource);
    linkGlobalFile(join(dotfilesRoot, "agents", "AGENTS.md"), join(configDir, "AGENTS.md"), "Global mode", debug);
    linkGlobalFile(configFile, join(configDir, "opencode.json"), "Global mode", debug);
    linkGlobalFile(cliConfigFile, join(configDir, "cli.json"), "Global mode", debug);
    rmSync(join(configDir, "plugins", "custom"), {recursive: true, force: true});

    for (const file of findFiles(agentsSource)) {
        linkGlobalFile(file, join(configDir, "agents", relative(agentsSource, file)), "Global mode", debug);
    }

    for (const file of findFiles(pluginsSource)) {
        const target = file.endsWith(".ts") || file.endsWith(".js")
            ? join(configDir, "plugins", relative(pluginsSource, file))
            : join(configDir, relative(pluginsSource, file));
        linkGlobalFile(file, target, "Global mode", debug);
    }

    if (skillErrors.length > 0) {
        throw new Error(`${skillErrors.length} skill(s) have invalid SKILL.md frontmatter`);
    }

    logInfo("Sync complete!");
}

function main(args: string[]): void {
    const options = parseOptions(args);

    if (options.sync) {
        syncGlobalOpencode(options.debug);

        return;
    }

    if (options.reinstall) {
        removeSkills();
    }

    installSkills();
    syncGlobalOpencode(options.debug);
}

if (import.meta.main) {
    try {
        main(process.argv.slice(2));
    } catch (error) {
        process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
        process.exit(1);
    }
}
