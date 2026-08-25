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

/** Run a program directly (no shell), capturing stdout/stderr. argv[0] is the executable. */
export function run(argv: string[], opts?: { cwd?: string }): RunResult {
  try {
    const r = Bun.spawnSync(argv, { cwd: opts?.cwd, stdin: "inherit", stdout: "pipe", stderr: "pipe" });
    return {
      code: r.exitCode ?? 1,
      ok: r.exitCode === 0,
      stdout: r.stdout ? r.stdout.toString() : "",
      stderr: r.stderr ? r.stderr.toString() : "",
    };
  } catch (err) {
    // Executable not found or failed to spawn — mirror a non-zero exit.
    return { code: 127, ok: false, stdout: "", stderr: err instanceof Error ? err.message : String(err) };
  }
}

/** Run a program directly, streaming stdio to the terminal. Returns true on exit 0. */
export function runInherit(argv: string[]): boolean {
  try {
    const r = Bun.spawnSync(argv, { stdin: "inherit", stdout: "inherit", stderr: "inherit" });
    return r.exitCode === 0;
  } catch {
    return false;
  }
}

/** Run a program directly (streaming), throwing errmsg if it exits non-zero. */
export function runAssert(argv: string[], errmsg?: string): void {
  if (!runInherit(argv)) {
    throw new Error(errmsg ?? `command failed: ${argv.join(" ")}`);
  }
}

/**
 * Run a POSIX shell pipeline via `/bin/sh -c` (macOS/Linux only).
 * Use ONLY for genuine shell constructs such as `curl … | bash`. On POSIX the
 * command is passed as a single argv element to sh, so there is no re-quoting
 * pitfall. Returns true on exit 0.
 */
export function sh(cmd: string): boolean {
  try {
    const r = Bun.spawnSync(["/bin/sh", "-c", cmd], {
      stdin: "inherit",
      stdout: "inherit",
      stderr: "inherit",
    });
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
  return runInherit(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command]);
}

/**
 * POSIX single-quote a string for safe interpolation into an sh() command.
 * Only needed when building a shell pipeline string for sh(); argv-based calls
 * never need quoting.
 */
export function shq(s: string): string {
  return "'" + s.replace(/'/g, "'\\''") + "'";
}
