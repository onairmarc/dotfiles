// provision/configurators/stripe_completion.ts
//
// Generates and installs the Stripe CLI shell completion script.
// Replicates install.sh:196-204.
//
// The Stripe CLI's `stripe completion` command writes a file named
// `stripe-completion.zsh` into its working directory. Running it with cwd=$HOME
// therefore produces $HOME/stripe-completion.zsh, which is then installed into
// the Oh My Zsh completions directory and archived under $HOME/.stripe/.
//
// All file handling is native node:fs so it works on macOS and Windows alike.
import {copyFileSync, existsSync, lstatSync, mkdirSync, renameSync, rmSync} from "node:fs";
import {run as exec} from "../lib/shell.ts";

/** lstat without throwing — returns null when the path does not exist. */
function lstatOrNull(path: string): ReturnType<typeof lstatSync> | null {
    try {
        return lstatSync(path);
    } catch {
        return null;
    }
}

export function run(): void {
    const home = process.env.HOME || "";
    const zsh = process.env.ZSH || home + "/.oh-my-zsh";
    const completionFile = home + "/stripe-completion.zsh";

// Stripe writes ./stripe-completion.zsh in the working directory.
    exec(["stripe", "completion"], {cwd: home});

// Ensure $HOME/.stripe is a directory. If a regular file sits there, remove it
// first (mirrors the original `[ ! -f "$HOME/.stripe" ]` guard).
    const stripeDir = home + "/.stripe";
    const stat = lstatOrNull(stripeDir);
    if (stat && stat.isFile() && !stat.isSymbolicLink()) {
        rmSync(stripeDir);
    }

    mkdirSync(stripeDir, {recursive: true});

// Install into the Oh My Zsh completions directory (best-effort), then archive
// the generated file under $HOME/.stripe/.
    const zshCompletions = zsh + "/completions";
    mkdirSync(zshCompletions, {recursive: true});

    if (existsSync(completionFile)) {
        copyFileSync(completionFile, zshCompletions + "/stripe-completion.sh");
        renameSync(completionFile, stripeDir + "/stripe-completion.zsh");
    }
}