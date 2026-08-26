import {lstatSync, readdirSync, readFileSync, readlinkSync, unlinkSync, writeFileSync} from "node:fs";
import {dirname, isAbsolute, join, resolve} from "node:path";
import * as platform from "./platform.ts";

const BAK_PREFIXES = [".zshrc.bak.", ".bashrc.bak."];

function removeBakFiles(dir: string): void {
    let names: string[];
    try {
        names = readdirSync(dir);
    } catch {
        return;
    }

    for (const name of names) {
        if (!BAK_PREFIXES.some((prefix) => name.startsWith(prefix))) {
            continue;
        }
        try {
            unlinkSync(join(dir, name));
        } catch {
            // best-effort
        }
    }
}

function resolveFile(path: string): string | null {
    let stat: ReturnType<typeof lstatSync>;
    try {
        stat = lstatSync(path);
    } catch {
        return null;
    }

    if (stat.isSymbolicLink()) {
        let link: string;
        try {
            link = readlinkSync(path);
        } catch {
            return null;
        }

        return isAbsolute(link) ? link : resolve(dirname(path), link);
    }

    return stat.isFile() ? path : null;
}

const START_MARK = "# >>> grok installer >>>";

const END_MARK = "# <<< grok installer <<<";

function stripGrokBlock(path: string): void {
    const target = resolveFile(path);
    if (!target) {
        return;
    }

    let content: string;
    try {
        content = readFileSync(target, "utf8");
    } catch {
        return;
    }

    if (!content.includes("grok installer")) {
        return;
    }

    const endedWithNl = content.endsWith("\n");
    const lines = content.split(/\r?\n/);
    if (endedWithNl && lines[lines.length - 1] === "") {
        lines.pop();
    }

    const kept: string[] = [];
    let skip = false;

    for (const line of lines) {
        if (line.includes(START_MARK)) {
            skip = true;
            continue;
        }

        if (line.includes(END_MARK)) {
            skip = false;
            continue;
        }

        if (!skip) {
            kept.push(line);
        }
    }

    writeFileSync(target, kept.join("\n") + (endedWithNl ? "\n" : ""));
}

export function cleanupAfterGrokInstall(): void {
    const home = platform.home();
    const df = platform.dotfilesRoot();

    removeBakFiles(home);
    removeBakFiles(df);
    stripGrokBlock(join(home, ".zshrc"));
    stripGrokBlock(join(home, ".bashrc"));
    stripGrokBlock(join(df, ".zshrc"));
}