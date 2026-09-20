// provision/configurators/windows_terminal.ts
//
// Adds the Windows Terminal input sequence OpenCode uses for Shift+Enter.
import {existsSync, readFileSync, writeFileSync} from "node:fs";
import {join} from "node:path";

const ACTION_ID = "User.sendInput.ShiftEnterCustom";

interface Action {
    command: {
        action: "sendInput";
        input: string;
    };
    id: string;
}

interface Keybinding {
    keys: string;
    id: string;
}

interface Settings {
    actions?: Action[];
    keybindings?: Keybinding[];
    [key: string]: unknown;
}

const action: Action = {
    command: {action: "sendInput", input: "\u001b[13;2u"},
    id: ACTION_ID,
};

const keybinding: Keybinding = {
    keys: "shift+enter",
    id: ACTION_ID,
};

function settingsFrom(path: string): Settings {
    const parsed: unknown = JSON.parse(readFileSync(path, "utf8"));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        throw new Error(`${path} must contain a JSON object`);
    }

    return parsed as Settings;
}

function synchronizeSettings(path: string): void {
    const settings = settingsFrom(path);
    const actions = settings.actions ?? [];
    const keybindings = settings.keybindings ?? [];

    const conflictingKeybinding = keybindings.find((binding) =>
        binding.keys === keybinding.keys && binding.id !== ACTION_ID
    );
    if (conflictingKeybinding) {
        throw new Error(`${path} already assigns Shift+Enter to ${conflictingKeybinding.id}`);
    }

    settings.actions = [...actions.filter((entry) => entry.id !== ACTION_ID), action];
    settings.keybindings = [...keybindings.filter((entry) => entry.id !== ACTION_ID), keybinding];
    writeFileSync(path, `${JSON.stringify(settings, null, 2)}\n`);
}

export function run(): void {
    const localAppData = process.env.LOCALAPPDATA;
    if (!localAppData) throw new Error("LOCALAPPDATA is not set");

    const settingsPaths = [
        join(localAppData, "Packages", "Microsoft.WindowsTerminal_8wekyb3d8bbwe", "LocalState", "settings.json"),
        join(localAppData, "Packages", "Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe", "LocalState", "settings.json"),
        join(localAppData, "Microsoft", "Windows Terminal", "settings.json"),
    ];

    for (const settingsPath of settingsPaths) {
        if (existsSync(settingsPath)) synchronizeSettings(settingsPath);
    }
}
