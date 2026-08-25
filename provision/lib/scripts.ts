// provision/lib/scripts.ts
//
// Script runner for the Bun provisioner.
// Scripts are NOT tracked in state.json and always re-run on each provision.
// The expectation is that the target installer script is itself idempotent.
//
// Supported entry kinds:
//   { kind: "curl", url: "https://...", pipe_to: "bash" }
//     → curl -fsSL <url> | <env> <pipe_to> <args>
//   { kind: "powershell", url: "https://..." }
//     → powershell -NoProfile -ExecutionPolicy Bypass -Command "irm '<url>' | iex"
//
// Additional optional fields:
//   args              Extra arguments appended to pipe_to (curl kind only).
//   env               Environment variable overrides for the installer process.
//                     curl: KEY=VALUE prefixes on the right side of the pipe.
//                     powershell: $env:KEY='VALUE'; prefixes inside -Command.
//   post              Shell command run after the primary install succeeds.
//   skip_if_env_set   Skip when the named env var is set and non-empty.
import { sh, powershell, shq } from "./shell.ts";

export interface ScriptEntry {
    kind: "curl" | "powershell";
    url: string;
    pipe_to?: string;
    args?: string;
    env?: Record<string, string>;
    post?: string;
    skip_if_env_set?: string;
}

function runPost(entry: ScriptEntry): void {
    if (!entry.post || entry.post === "") {
        return;
    }

    // post steps are POSIX shell snippets (mac-only cleanup).
    if (!sh(entry.post)) {
        throw new Error("script post-step failed: " + entry.post);
    }
}

/** Return whether a script entry should be skipped, plus a short reason. */
export function shouldSkip(entry: ScriptEntry): [boolean, string?] {
    if (!entry || typeof entry !== "object") {
        return [false];
    }

    const name = entry.skip_if_env_set;
    if (name && name !== "") {
        const v = process.env[name];
        if (v && v !== "") {
            return [true, `$${name} is set (${v})`];
        }
    }

    return [false];
}

/**
 * Run a script entry.
 * Throws if the command exits non-zero.
 * Callers should check shouldSkip() first if they want a clean skip path.
 */
export function run(entry: ScriptEntry): void {
    if (!entry || typeof entry !== "object") {
        throw new Error("scripts.run: entry must be an object");
    }

    const [skip] = shouldSkip(entry);
    if (skip) {
        return;
    }

    if (entry.kind === "curl") {
        if (!entry.url) throw new Error("scripts.run: curl entry must have a url field");
        if (!entry.pipe_to) throw new Error("scripts.run: curl entry must have a pipe_to field");
        // Env must apply to pipe_to (the installer). Prefixing curl alone is a no-op
        // for the script: `VAR=x curl | bash` only sets VAR on curl, not bash.
        let envPrefix = "";

        if (entry.env && typeof entry.env === "object") {
            for (const [k, v] of Object.entries(entry.env)) {
                envPrefix += `${k}=${shq(v)} `;
            }
        }

        const trailing = entry.args && entry.args !== "" ? " " + entry.args : "";
        const cmd = `curl -fsSL ${shq(entry.url)} | ${envPrefix}${entry.pipe_to}${trailing}`;
        // Genuine `curl … | bash` pipeline — needs a POSIX shell (macOS).
        if (!sh(cmd)) {
            throw new Error(`script failed (curl|${entry.pipe_to}): ${entry.url}`);
        }

        runPost(entry);
    } else if (entry.kind === "powershell") {
        if (!entry.url) throw new Error("scripts.run: powershell entry must have a url field");
        // Build $env:KEY='VALUE'; prefixes so the installer process receives them.
        // Escape single quotes for PowerShell single-quoted strings.
        let envPrefix = "";

        if (entry.env && typeof entry.env === "object") {
            for (const [k, v] of Object.entries(entry.env)) {
                const val = String(v).replace(/'/g, "''");
                envPrefix += `$env:${k}='${val}'; `;
            }
        }

        // irm | iex is the canonical Windows install pattern (e.g. xAI Grok CLI).
        // URL is single-quoted inside -Command; escape any embedded single quotes.
        const url = entry.url.replace(/'/g, "''");
        const command = `${envPrefix}irm '${url}' | iex`;
        if (!powershell(command)) {
            throw new Error(`script failed (powershell irm|iex): ${entry.url}`);
        }

        runPost(entry);
    } else {
        throw new Error("scripts.run: unsupported kind: " + String(entry.kind));
    }
}