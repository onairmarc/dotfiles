import {mkdirSync, unlinkSync, writeFileSync} from "node:fs";
import {join} from "node:path";
import * as platform from "../lib/platform.ts";
import {run, runAssert, runInherit} from "../lib/shell.ts";

const LABEL = "com.user.capslock-escape";

function agentLoaded(): boolean {
    const {ok, stdout} = run(["launchctl", "list"]);
    return ok && stdout.includes(LABEL);
}

function firstAfterEq(text: string, needle: string): string {
    for (const line of text.split("\n")) {
        if (!line.includes(needle)) {
            continue;
        }

        const idx = line.indexOf("= ");
        if (idx >= 0) {
            return line.slice(idx + 2).trim();
        }
    }

    return "";
}

function keyboardIds(): { vendor: string; product: string } | null {
    const {stdout} = run(["ioreg", "-c", "AppleEmbeddedKeyboard", "-r"]);
    const vendor = firstAfterEq(stdout, "VendorID");
    const product = firstAfterEq(stdout, '"ProductID"');
    if (vendor === "" || product === "") {
        return null;
    }

    return {vendor, product};
}

function modifierMappingKey(ids: { vendor: string; product: string }): string {
    return `com.apple.keyboard.modifiermapping.${ids.vendor}-${ids.product}-0`;
}

function refreshPrefs(): void {
    run(["killall", "-HUP", "cfprefsd"]);
    run(["killall", "SystemUIServer"]);
}

function applyDefaultsMapping(): void {
    const ids = keyboardIds();
    if (!ids) {
        return;
    }

    const key = modifierMappingKey(ids);
    run(["defaults", "-currentHost", "delete", "-g", key]);
    runInherit([
        "defaults",
        "-currentHost",
        "write",
        "-g",
        key,
        "-array",
        "<dict><key>HIDKeyboardModifierMappingDst</key><integer>53</integer><key>HIDKeyboardModifierMappingSrc</key><integer>0</integer></dict>",
    ]);

    run(["defaults", "-currentHost", "read", "-g"]);
    refreshPrefs();
    run(["/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", "-u"]);
}

function launchAgentPath(): string {
    return join(platform.home(), "Library", "LaunchAgents", `${LABEL}.plist`);
}

function removeDefaultsMapping(): void {
    const ids = keyboardIds();
    if (!ids) {
        return;
    }

    run(["defaults", "-currentHost", "delete", "-g", modifierMappingKey(ids)]);
    refreshPrefs();
}

function showUsage(): never {
    process.stdout.write(`Usage: ${process.argv[1]} [--enable|--disable]\n\n`);
    process.stdout.write("Options:\n");
    process.stdout.write("  --enable      Enable Caps Lock to Escape remapping\n");
    process.stdout.write("  --disable     Disable Caps Lock to Escape remapping\n");
    process.exit(1);
}

const COL_CYAN = "\x1b[0;36m";

const COL_GREEN = "\x1b[0;32m";

const COL_RESET = "\x1b[0m";

const COL_YELLOW = "\x1b[1;33m";

const HIDUTIL_CLEAR = '{"UserKeyMapping":[]}';

const HIDUTIL_SET =
    '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}';

const PLIST = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.capslock-escape</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--set</string>
        <string>{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
`;

export function disable(): void {
    process.stdout.write(`${COL_CYAN}Disabling Caps Lock to Escape remapping...${COL_RESET}\n`);
    run(["hidutil", "property", "--set", HIDUTIL_CLEAR]);
    removeDefaultsMapping();

    const plist = launchAgentPath();
    run(["launchctl", "unload", plist]);
    try {
        unlinkSync(plist);
        process.stdout.write(`${COL_GREEN}LaunchAgent removed.${COL_RESET}\n`);
    } catch {
        // already gone
    }

    process.stdout.write(`${COL_GREEN}Caps Lock remapping has been removed.${COL_RESET}\n`);
}

export function enable(): void {
    process.stdout.write(`${COL_CYAN}Enabling Caps Lock to Escape remapping...${COL_RESET}\n`);
    runAssert(["hidutil", "property", "--set", HIDUTIL_SET], "hidutil remap failed");
    applyDefaultsMapping();

    const plist = launchAgentPath();

    mkdirSync(join(platform.home(), "Library", "LaunchAgents"), {recursive: true});
    writeFileSync(plist, PLIST);
    run(["launchctl", "unload", plist]);
    runInherit(["launchctl", "load", plist]);

    if (agentLoaded()) {
        process.stdout.write(`${COL_GREEN}Caps Lock successfully remapped to Escape.${COL_RESET}\n`);
        process.stdout.write(
            `${COL_YELLOW}Note: The macOS keyboard shortcut settings UI will not reflect these changes. ${COL_RESET}\n`,
        );
    } else {
        process.stdout.write(`${COL_YELLOW}Caps Lock remapped for current session.${COL_RESET}\n`);
        process.stdout.write(`${COL_YELLOW}LaunchAgent created at: ${plist}${COL_RESET}\n`);
    }
}

export function runConfigurator(): void {
    enable();
}

export {runConfigurator as run};

if (import.meta.main) {
    const arg = process.argv[2] ?? "--enable";
    switch (arg) {
        case "--enable":
            enable();
            break;
        case "--disable":
            disable();
            break;
        case "--help":
            showUsage();
            break;
        default:
            showUsage();
    }
}