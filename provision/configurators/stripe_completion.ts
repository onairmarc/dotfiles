// provision/configurators/stripe_completion.ts
//
// Generates and installs the Stripe CLI shell completion script.
// Replicates install.sh:196-204.
//
// Steps:
//   1. Run `stripe completion` in $HOME to generate stripe-completion.zsh.
//   2. Ensure $HOME/.stripe/ directory exists (removing any non-directory at
//      that path first, mirroring the original `[ ! -f "$HOME/.stripe" ]` guard).
//   3. Copy the completion file to $ZSH/completions/stripe-completion.sh
//      (Oh My Zsh completions directory).
//   4. Move the completion file into $HOME/.stripe/.
import {shellExec, shellOk, shq} from "../lib/shell.ts";

export function run(): void {
    const home = process.env.HOME || "";
    const zsh = process.env.ZSH || home + "/.oh-my-zsh";

// Generate the completion file in $HOME so we have a predictable path.
    const completionFile = home + "/stripe-completion.zsh";

    shellExec(`cd ${shq(home)} && stripe completion 2>/dev/null`);

// Ensure $HOME/.stripe is a directory.
// If it exists as a regular file, remove it first (mirrors install.sh logic).
    const stripeDir = home + "/.stripe";
    if (shellOk(`test -f ${shq(stripeDir)} && ! test -L ${shq(stripeDir)}`)) {
        shellExec(`rm -f ${shq(stripeDir)}`);
    }

    shellExec(`mkdir -p ${shq(stripeDir)}`);

// Copy to Oh My Zsh completions directory (best-effort).
    const zshCompletions = zsh + "/completions";
    shellExec(`mkdir -p ${shq(zshCompletions)}`);

    if (shellOk(`test -f ${shq(completionFile)}`)) {
        shellExec(`cp ${shq(completionFile)} ${shq(zshCompletions + "/stripe-completion.sh")}`);

        // Move the original into ~/.stripe/.
        shellExec(`mv ${shq(completionFile)} ${shq(stripeDir + "/stripe-completion.zsh")}`);
    }
}