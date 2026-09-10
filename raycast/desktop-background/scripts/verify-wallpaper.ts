// Opt-in live regression check: changes the desktop, then restores each screen.
import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {basename} from "node:path";
import {fileURLToPath} from "node:url";
import {macBackgroundCommands} from "../../../provision/lib/mac_background.ts";
import {listImages} from "../src/images.ts";

if (process.platform !== "darwin") {
    throw new Error("This live wallpaper check requires macOS");
}

interface Desktop {
    image: string;
    scaling: number | null;
}

const snapshotScript = `ObjC.import("AppKit");
const workspace = $.NSWorkspace.sharedWorkspace;
const screens = $.NSScreen.screens;
const result = [];
for (let index = 0; index < screens.count; index += 1) {
    const screen = screens.objectAtIndex(index);
    const options = workspace.desktopImageOptionsForScreen(screen);
    result.push({
        image: ObjC.unwrap(workspace.desktopImageURLForScreen(screen).path),
        scaling: ObjC.unwrap(options.objectForKey($.NSWorkspaceDesktopImageScalingKey))
    });
}
JSON.stringify(result);`;

function snapshot(): Desktop[] {
    return JSON.parse(execFileSync("/usr/bin/osascript", ["-l", "JavaScript", "-e", snapshotScript], {encoding: "utf8"}));
}

const original = snapshot();
assert.ok(original.length > 0, "No screens available");
const directory = fileURLToPath(new URL("../../../backgrounds/", import.meta.url));
const available = await listImages(directory);
const images = [...available.filter((image) => image !== original[0].image), ...available.filter((image) => image === original[0].image)];

try {
    for (const image of images) {
        for (const {argv} of macBackgroundCommands(image)) {
            execFileSync(argv[0], argv.slice(1));
        }

        // Catch a successful set followed by WallpaperAgent restoring the old image.
        await Bun.sleep(2000);
        const actual = snapshot();
        assert.equal(actual.length, original.length, "Connected screens changed during the test");
        for (const desktop of actual) {
            assert.equal(desktop.image, image, "macOS restored a different wallpaper");
            assert.equal(desktop.scaling, 1, "Wallpaper must stretch to fill");
        }
        console.log(`PASS ${basename(image)}: image and stretch-to-fill persisted`);
    }
} finally {
    execFileSync("/usr/bin/osascript", ["-l", "JavaScript", "-e", `ObjC.import("AppKit");
function run(argv) {
    const original = JSON.parse(argv[0]);
    const workspace = $.NSWorkspace.sharedWorkspace;
    const screens = $.NSScreen.screens;
    if (Number(screens.count) !== original.length) throw new Error("Screen count changed; cannot restore wallpaper by screen index");
    for (let index = 0; index < screens.count; index += 1) {
        const screen = screens.objectAtIndex(index);
        const options = workspace.desktopImageOptionsForScreen(screen).mutableCopy;
        if (original[index].scaling == null) options.removeObjectForKey($.NSWorkspaceDesktopImageScalingKey);
        else options.setObjectForKey($(original[index].scaling), $.NSWorkspaceDesktopImageScalingKey);
        const error = Ref();
        if (!workspace.setDesktopImageURLForScreenOptionsError(
            $.NSURL.fileURLWithPath($(original[index].image)), screen, options, error
        )) throw new Error(ObjC.unwrap(error[0].localizedDescription));
    }
}`, JSON.stringify(original)]);
}
