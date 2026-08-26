import {copyFileSync, mkdirSync, readdirSync, rmSync, statSync} from "node:fs";
import {basename, dirname, join} from "node:path";

function ask(message: string): string | null {
    const answer = prompt(message);
    if (answer === null) {
        return null;
    }

    return answer.trim();
}

function existsDir(path: string): boolean {
    try {
        return statSync(path).isDirectory();
    } catch {
        return false;
    }
}

const COL_RED = "\x1b[1;31m";

const COL_RESET = "\x1b[0m";

function logError(msg: string): void {
    process.stderr.write(`${COL_RED}${msg}${COL_RESET}\n`);
}

const COL_BLUE = "\x1b[34m";

function logInfo(msg: string): void {
    process.stdout.write(`${COL_BLUE}${msg}${COL_RESET}\n`);
}

function xmlFiles(dir: string): string[] {
    let names: string[];
    try {
        names = readdirSync(dir);
    } catch {
        return [];
    }

    return names.filter((n) => n.endsWith(".xml")).map((n) => join(dir, n));
}

function existsFile(path: string): boolean {
    try {
        return statSync(path).isFile();
    } catch {
        return false;
    }
}

function stamp(): string {
    const d = new Date();
    const p = (n: number) => String(n).padStart(2, "0");
    return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

const COL_GREEN = "\x1b[0;32m";

function logSuccess(msg: string): void {
    process.stdout.write(`${COL_GREEN}${msg}${COL_RESET}\n`);
}

function copyKeymaps(selectedIde: string, jetbrainsDir: string, keymapSource: string): void {
    const targetDir = join(jetbrainsDir, selectedIde, "keymaps");

    if (!existsDir(keymapSource)) {
        logError(`Error: Source keymaps directory not found at: ${keymapSource}`);
        process.exit(1);
    }

    if (!existsDir(targetDir)) {
        logInfo(`Creating keymaps directory: ${targetDir}`);
        mkdirSync(targetDir, {recursive: true});
    }

    logInfo(`Copying keymaps from: ${keymapSource}`);
    logInfo(`To: ${targetDir}`);
    process.stdout.write("\n");

    const sources = xmlFiles(keymapSource);
    let backupCreated = false;

    for (const keymap of sources) {
        const filename = basename(keymap);
        if (existsFile(join(targetDir, filename)) && !backupCreated) {
            const backupDir = join(targetDir, `backup_${stamp()}`);
            logInfo(`Existing keymaps found. Creating backup at: ${backupDir}`);
            mkdirSync(backupDir, {recursive: true});

            for (const existing of xmlFiles(targetDir)) {
                try {
                    copyFileSync(existing, join(backupDir, basename(existing)));
                } catch {
                    // best-effort
                }
            }

            logInfo("Clearing existing keymaps from target directory...");

            for (const existing of xmlFiles(targetDir)) {
                rmSync(existing, {force: true});
            }

            backupCreated = true;
        }
    }

    let copiedCount = 0;

    for (const keymap of sources) {
        const filename = basename(keymap);
        try {
            copyFileSync(keymap, join(targetDir, filename));
            logSuccess(`✓ Copied: ${filename}`);
            copiedCount += 1;
        } catch {
            logError(`✗ Failed to copy: ${filename}`);
        }
    }

    process.stdout.write("\n");

    if (copiedCount > 0) {
        logSuccess(`Successfully copied ${copiedCount} keymap(s) to ${selectedIde}`);
        process.stdout.write("\n");
        logInfo("The keymaps should now be available in your IDE under:");
        logInfo("Settings → Keymap → [Select your custom keymap]");
        logInfo("You may need to restart your IDE for the changes to take effect.");
    } else {
        logError("No keymaps were copied.");
    }
}

function detectPlatform(): { jetbrainsDir: string; platform: string } {
    if (process.platform === "win32") {
        const appdata = process.env.APPDATA;
        if (!appdata) {
            logError("Error: APPDATA environment variable not found");
            process.exit(1);
        }

        return {jetbrainsDir: join(appdata, "JetBrains"), platform: "Windows"};
    }

    if (process.platform === "darwin") {
        const home = process.env.HOME || process.env.USERPROFILE || "";

        return {
            jetbrainsDir: join(home, "Library", "Application Support", "JetBrains"),
            platform: "macOS",
        };
    }

    logError("Error: Unsupported platform. This script supports Windows and macOS only.");
    process.exit(1);
}

const IDES = [
    "GoLand",
    "PhpStorm",
    "WebStorm",
    "IntelliJIdea",
    "Rider",
    "PyCharm",
    "CLion",
    "RubyMine",
    "DataGrip",
    "AndroidStudio",
];

function discoverIdeVersions(jetbrainsDir: string): string[] {
    if (!existsDir(jetbrainsDir)) {
        logError(`Error: JetBrains directory not found at: ${jetbrainsDir}`);

        return [];
    }

    let names: string[];
    try {
        names = readdirSync(jetbrainsDir);
    } catch {
        logError(`Error: JetBrains directory not found at: ${jetbrainsDir}`);

        return [];
    }

    const available: string[] = [];

    for (const ide of IDES) {
        const re = new RegExp(`^${ide}[0-9]`);

        for (const name of names) {
            if (re.test(name) && existsDir(join(jetbrainsDir, name))) {
                available.push(name);
            }
        }
    }

    if (available.length === 0) {
        logError(`No compatible JetBrains IDEs found in: ${jetbrainsDir}`);
        logInfo("Looking for directories matching pattern: {IDE}{version} with existing keymaps folder");
        process.stdout.write(`Supported IDEs: ${IDES.join(" ")}\n`);
    }

    return available;
}

function getUserSelection(versions: string[]): string {
    while (true) {
        const selection = ask(`Please select an IDE version (1-${versions.length}): `);
        if (selection === null) {
            logError("Operation cancelled.");
            process.exit(1);
        }

        if (/^\d+$/.test(selection)) {
            const n = Number(selection);
            if (n >= 1 && n <= versions.length) {
                return versions[n - 1];
            }
        }

        process.stderr.write(`Invalid selection. Please enter a number between 1 and ${versions.length}.\n`);
    }
}

function main(): void {
    const dfRoot = process.env.DF_ROOT_DIRECTORY || dirname(import.meta.dir);
    const keymapSource = join(dfRoot, "JetBrains", "keymaps");

    logInfo("JetBrains Keymap Copy Utility");
    logInfo("=============================");
    process.stdout.write("\n");

    const {jetbrainsDir, platform} = detectPlatform();
    logInfo(`Detected platform: ${platform}`);
    logInfo(`JetBrains directory: ${jetbrainsDir}`);
    logInfo(`Keymap source: ${keymapSource}`);
    process.stdout.write("\n");

    const versions = discoverIdeVersions(jetbrainsDir);
    if (versions.length === 0) {
        process.exit(1);
    }

    let selected: string;

    if (versions.length === 1) {
        logInfo(`Found 1 compatible IDE version: ${versions[0]}`);

        const confirm = ask(`Copy keymaps to ${versions[0]}? (y/N): `);
        if (confirm === null || !/^[Yy]$/.test(confirm)) {
            logError("Operation cancelled.");

            return;
        }

        selected = versions[0];
    } else {
        process.stdout.write(`Available JetBrains IDE versions on ${platform}:\n\n`);
        versions.forEach((v, i) => {
            process.stdout.write(`${i + 1}. ${v}\n`);
        });

        process.stdout.write("\n");
        selected = getUserSelection(versions);
        process.stdout.write("\n");
        logInfo(`Selected: ${selected}`);

        const confirm = ask(`Copy keymaps to ${selected}? (y/N): `);
        if (confirm === null || !/^[Yy]$/.test(confirm)) {
            logError("Operation cancelled.");

            return;
        }

        process.stdout.write("\n");
    }

    copyKeymaps(selected, jetbrainsDir, keymapSource);
}

if (import.meta.main) {
    main();
}