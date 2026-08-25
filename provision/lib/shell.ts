// provision/lib/shell.ts
//
// Process execution helpers for the Bun provisioner.
//
// Prefer run()/runInherit()/runAssert(): they spawn a program directly by argv
// with NO intermediate shell, so there is no quoting or word-splitting to get
// wrong and, critically, no cmd.exe on Windows. (cmd.exe reparses a /c argument
// and fails on anything but builtins, which is why piping to findstr/where broke
// every tool install.)
//
// sh() and powershell() exist only for the few cases that are genuinely a shell
// construct — a `curl … | bash` pipeline (macOS) or an `irm … | iex` PowerShell
// installer (Windows).
export interface RunResult {
    code: number;
    ok: boolean;
    stdout: string;
    stderr: string;
}

/**
 * Absolute path to Windows PowerShell. Bun on Windows cannot spawn the bare name
 * "powershell" by PATH lookup (it raises EPERM), so the full path is required.
 * The "v1.0" directory is legacy naming and is correct on all modern Windows.
 */
function powershellExe(): string {
    const root = process.env.SystemRoot || "C:\\Windows";
    return root + "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
}

/** Run a program directly, streaming stdio to the terminal. Returns true on exit 0. */
export function runInherit(argv: string[]): boolean {
    try {
        const r = Bun.spawnSync(argv, {stdin: "inherit", stdout: "inherit", stderr: "inherit"});
        return r.exitCode === 0;
    } catch {
        return false;
    }
}

/**
 * Run a Windows PowerShell `-Command` string via powershell.exe directly.
 * powershell.exe uses standard argv parsing (unlike cmd.exe), so the command is
 * passed as one argument safely. Returns true on exit 0.
 */
export function powershell(command: string): boolean {
    return runInherit([powershellExe(), "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command]);
}

/** Run a program directly (no shell), capturing stdout/stderr. argv[0] is the executable. */
export function run(argv: string[], opts?: { cwd?: string }): RunResult {
    try {
        const r = Bun.spawnSync(argv, {cwd: opts?.cwd, stdin: "inherit", stdout: "pipe", stderr: "pipe"});

        return {
            code: r.exitCode ?? 1,
            ok: r.exitCode === 0,
            stdout: r.stdout ? r.stdout.toString() : "",
            stderr: r.stderr ? r.stderr.toString() : "",
        };
    } catch (err) {
        // Executable not found or failed to spawn — mirror a non-zero exit.
        return {code: 127, ok: false, stdout: "", stderr: err instanceof Error ? err.message : String(err)};
    }
}

/** Run a program directly (streaming), throwing errmsg if it exits non-zero. */
export function runAssert(argv: string[], errmsg?: string): void {
    if (!runInherit(argv)) {
        throw new Error(errmsg ?? `command failed: ${argv.join(" ")}`);
    }
}

/**
 * Run a shell pipeline for genuine shell constructs such as `curl … | bash`.
 * The command is passed as a single argv element to the shell, so there is no
 * re-quoting pitfall. Returns true on exit 0.
 *
 * On macOS/Linux this is `/bin/sh`. On Windows it is `bash` resolved from PATH —
 * the manifest's curl installers are bash scripts, so a POSIX shell (Git Bash,
 * installed alongside git by install.ps1) is required; cmd.exe cannot run them.
 */
export function sh(cmd: string): boolean {
    const argv = process.platform === "win32" ? ["bash", "-c", cmd] : ["/bin/sh", "-c", cmd];
    try {
        const r = Bun.spawnSync(argv, {stdin: "inherit", stdout: "inherit", stderr: "inherit"});
        return r.exitCode === 0;
    } catch {
        return false;
    }
}

/**
 * POSIX single-quote a string for safe interpolation into an sh() command.
 * Only needed when building a shell pipeline string for sh(); argv-based calls
 * never need quoting.
 */
export function shq(s: string): string {
    return "'" + s.replace(/'/g, "'\\''") + "'";
}