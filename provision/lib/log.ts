// Detect whether colored output should be used.
function useColor(): boolean {
    if (process.env.NO_COLOR) {
        return false;
    }

    return process.stdout.isTTY === true;
}

const COLOR_ENABLED = useColor();

// provision/lib/log.ts
//
// Colored logging helpers for the Bun provisioner.
// Colors are emitted only when stdout is a TTY and $NO_COLOR is unset.
// ANSI escape codes.
const RESET = "\x1b[0m";

function colorize(color: string, text: string): string {
    if (COLOR_ENABLED) {
        return color + text + RESET;
    }

    return text;
}

const BOLD = "\x1b[1m";
const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const WHITE = "\x1b[37m";
const YELLOW = "\x1b[33m";

/** Print an error message (red) to stderr. */
export function error(label: string, msg?: string): void {
    const line = msg ? `${label}: ${msg}` : label;
    process.stderr.write(colorize(RED, "  ✗ " + line) + "\n");
}

/** Print an informational message (white). */
export function info(label: string, msg?: string): void {
    const line = msg ? `${label}: ${msg}` : label;
    process.stdout.write(colorize(WHITE, "    " + line) + "\n");
}

/** Print a success / already-done message (green). */
export function ok(label: string, msg?: string): void {
    const line = msg ? `${label}: ${msg}` : label;
    process.stdout.write(colorize(GREEN, "  ✓ " + line) + "\n");
}

/** Print a step header (bold cyan) — used for section separators. */
export function step(label: string): void {
    process.stdout.write(colorize(BOLD + CYAN, "==> " + label) + "\n");
}

/** Print a warning message (yellow) to stderr. */
export function warn(label: string, msg?: string): void {
    const line = msg ? `${label}: ${msg}` : label;
    process.stderr.write(colorize(YELLOW, "  ! " + line) + "\n");
}