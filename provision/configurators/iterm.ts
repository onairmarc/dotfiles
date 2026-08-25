// provision/configurators/iterm.ts
//
// Configures iTerm2 font settings.
// Replicates install.sh:25-45 (configure_iterm function).
//
// Sets JetBrainsMono-Regular 18pt as both the normal and non-ASCII font
// using `defaults write` and `/usr/libexec/PlistBuddy`.
import {shellExec, shq} from "../lib/shell.ts";

export function run(): void {
    const fontName = "JetBrainsMono-Regular";
    const fontSize = "18";
    const fontSpec = fontName + " " + fontSize;
    const home = process.env.HOME || "";
    const prefsDir = home + "/Library/Preferences";
    const plist = prefsDir + "/com.googlecode.iterm2.plist";

// Ensure the preferences directory exists.
    shellExec(`mkdir -p ${shq(prefsDir)}`);

// Configure via defaults(1).
    shellExec(`defaults write com.googlecode.iterm2 "Normal Font" -string ${shq(fontSpec)}`);
    shellExec(`defaults write com.googlecode.iterm2 "Non Ascii Font" -string ${shq(fontSpec)}`);
    shellExec(`defaults write com.googlecode.iterm2 UseNonASCIIFont -bool true`);

// Update the plist bookmarks profile (best-effort; ignore errors if no
// profile exists yet — PlistBuddy returns non-zero in that case).
    shellExec(
        `/usr/libexec/PlistBuddy -c "Set :New\\ Bookmarks:0:Normal\\ Font ${fontSpec}" ${shq(plist)} 2>/dev/null || true`,
    );

    shellExec(
        `/usr/libexec/PlistBuddy -c "Set :New\\ Bookmarks:0:Non\\ Ascii\\ Font ${fontSpec}" ${shq(plist)} 2>/dev/null || true`,
    );

    shellExec(
        `/usr/libexec/PlistBuddy -c "Set :New\\ Bookmarks:0:Use\\ Non-ASCII\\ Font true" ${shq(plist)} 2>/dev/null || true`,
    );
}