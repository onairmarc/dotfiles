import {closeMainWindow, getPreferenceValues, showHUD} from "@raycast/api";
import {execFile} from "node:child_process";
import {homedir} from "node:os";
import {basename, join, resolve} from "node:path";
import {promisify} from "node:util";
import {macBackgroundCommands} from "../../../provision/lib/mac_background.ts";
import {listImages, selectImage} from "./images";

const execute = promisify(execFile);

export async function rotateBackground(direction: 1 | -1): Promise<void> {
    await closeMainWindow();

    try {
        const preferences = getPreferenceValues<{backgroundsDirectory?: string}>();
        const configured = preferences.backgroundsDirectory;
        const directory = configured
            ? resolve(configured.startsWith("~/") ? join(homedir(), configured.slice(2)) : configured)
            : join(homedir(), "Documents/GitHub/dotfiles/backgrounds");
        const images = await listImages(directory);
        const {stdout} = await execute("/usr/bin/osascript", [
            "-e",
            'tell application "System Events" to get picture of first desktop',
        ], {timeout: 30_000});
        const image = selectImage(images, stdout.trim(), direction);

        for (const {argv, message} of macBackgroundCommands(image)) {
            const [file, ...args] = argv;
            try {
                await execute(file, args, {timeout: 30_000});
            } catch (error) {
                throw new Error(message, {cause: error});
            }
        }

        await showHUD(`Background: ${basename(image)}`);
    } catch (error) {
        console.error(error);
        await showHUD(error instanceof Error ? error.message : "Could not change the desktop background");
    }
}
