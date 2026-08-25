// provision/configurators/iterm.ts
//
// Configures iTerm2 font settings.
// Replicates install.sh:25-45 (configure_iterm function).
//
// Sets JetBrainsMono-Regular 18pt as both the normal and non-ASCII font using
// `defaults write` and `/usr/libexec/PlistBuddy`. Each tool is invoked directly
// by argv (no shell), so the profile-key strings need no shell escaping.
import {mkdirSync} from "node:fs";
import {run as exec, runInherit} from "../lib/shell.ts";

export function run(): void {
    const fontName = "JetBrainsMono-Regular";
    const fontSize = "18";
    const fontSpec = fontName + " " + fontSize;
    const home = process.env.HOME || "";
    const prefsDir = home + "/Library/Preferences";
    const plist = prefsDir + "/com.googlecode.iterm2.plist";

// Ensure the preferences directory exists.
    mkdirSync(prefsDir, {recursive: true});

// Configure via defaults(1).
    runInherit(["defaults", "write", "com.googlecode.iterm2", "Normal Font", "-string", fontSpec]);
    runInherit(["defaults", "write", "com.googlecode.iterm2", "Non Ascii Font", "-string", fontSpec]);
    runInherit(["defaults", "write", "com.googlecode.iterm2", "UseNonASCIIFont", "-bool", "true"]);

// Update the plist bookmarks profile (best-effort; PlistBuddy exits non-zero
// when no profile exists yet — the return value is intentionally ignored).
// The whole "Set :… value" string is a single argument to -c.
    exec(["/usr/libexec/PlistBuddy", "-c", `Set :New Bookmarks:0:Normal Font ${fontSpec}`, plist]);
    exec(["/usr/libexec/PlistBuddy", "-c", `Set :New Bookmarks:0:Non Ascii Font ${fontSpec}`, plist]);
    exec(["/usr/libexec/PlistBuddy", "-c", `Set :New Bookmarks:0:Use Non-ASCII Font true`, plist]);
}