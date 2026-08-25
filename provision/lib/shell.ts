// provision/lib/shell.ts
//
// Shell execution helper for the Bun provisioner.
//
// Mirrors Lua's os.execute(cmd): the command string is handed to the
// platform's default shell (`cmd.exe /c` on Windows, `/bin/sh -c` elsewhere),
// with stdio inherited so installer output streams straight to the terminal.
const IS_WINDOWS = process.platform === "win32";

/**
 * Run a command string through the platform shell.
 * @returns true when the process exits 0.
 */
export function shellOk(cmd: string): boolean {
    const argv = IS_WINDOWS ? ["cmd.exe", "/c", cmd] : ["/bin/sh", "-c", cmd];
    const result = Bun.spawnSync(argv, {
        stdin: "inherit",
        stdout: "inherit",
        stderr: "inherit",
    });

    return result.exitCode === 0;
}

/** Run a command string, throwing the given error message if it exits non-zero. */
export function shellAssert(cmd: string, errmsg?: string): void {
    if (!shellOk(cmd)) {
        throw new Error(errmsg ?? `command failed: ${cmd}`);
    }
}

/**
 * Run a command string, ignoring the exit status.
 * Used where the original code called os.execute() without checking the result.
 */
export function shellExec(cmd: string): void {
    shellOk(cmd);
}

/**
 * POSIX single-quote a string for safe interpolation into an `/bin/sh` command.
 * Replaces the Lua `%q` format specifier used throughout the shell-side code.
 */
export function shq(s: string): string {
    return "'" + s.replace(/'/g, "'\\''") + "'";
}