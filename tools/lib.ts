import {cpSync, type Dirent, lstatSync, readdirSync, readlinkSync, symlinkSync} from "node:fs";
import {dirname, isAbsolute, join} from "node:path";

export function exists(path: string): boolean {
    try {
        lstatSync(path);

        return true;
    } catch {
        return false;
    }
}

export function isDirectory(path: string): boolean {
    try {
        return lstatSync(path).isDirectory();
    } catch {
        return false;
    }
}

export function homeDirectory(): string {
    return process.env.HOME || process.env.USERPROFILE || "";
}

export function gitTopLevel(cwd: string): string | null {
    const result = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"], {
        cwd,
        stdout: "pipe",
        stderr: "pipe",
    });

    return result.exitCode === 0 ? result.stdout.toString().trim() : null;
}

export function findFiles(root: string): string[] {
    const files: string[] = [];
    walk(root, (path, entry) => {
        if (entry.isFile()) {
            files.push(path);
        }
    });

    return files;
}

export function findFilesNamed(root: string, name: string): string[] {
    const files: string[] = [];
    walk(root, (path, entry) => {
        if (entry.isFile() && entry.name === name) {
            files.push(path);
        }
    });

    return files;
}

export function findDirectoriesContaining(root: string, fileName: string): string[] {
    const directories: string[] = [];
    walk(root, (path, entry) => {
        if (entry.isFile() && entry.name === fileName) {
            directories.push(dirname(path));
        }
    });

    return directories;
}

export function alreadyWriteThrough(linkPath: string, referent: string): boolean {
    try {
        return lstatSync(linkPath).isSymbolicLink() && readlinkSync(linkPath) === referent;
    } catch {
        return false;
    }
}

export function createWriteThroughLink(referent: string, linkPath: string): void {
    symlinkSync(referent, linkPath, writeThroughType(referent, linkPath));
}

export function copyDirectory(source: string, target: string): void {
    cpSync(source, target, {recursive: true});
}

function walk(root: string, visit: (path: string, entry: Dirent) => void): void {
    let entries: Dirent[];
    try {
        entries = readdirSync(root, {withFileTypes: true});
    } catch {
        return;
    }

    for (const entry of entries) {
        const path = join(root, entry.name);
        if (entry.isDirectory()) {
            walk(path, visit);
        } else {
            visit(path, entry);
        }
    }
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

function resolveReferent(referent: string, linkPath: string): string {
    return isAbsolute(referent) ? referent : join(dirname(linkPath), referent);
}
