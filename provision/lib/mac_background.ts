// Shared argv commands for provisioning and the local Raycast extension.
// Keep image paths as arguments rather than interpolating them into the script.
export function macBackgroundCommands(image: string): { argv: string[]; message: string }[] {
    // NSWorkspace sets the image and scaling together. Rewriting Index.plist and
    // restarting WallpaperAgent can restore an old image before macOS saves the new one.
    const script = `ObjC.import("AppKit");
function run(argv) {
    const workspace = $.NSWorkspace.sharedWorkspace;
    const screens = $.NSScreen.screens;
    const url = $.NSURL.fileURLWithPath($(argv[0]));
    if (Number(screens.count) === 0) throw new Error("No screens available");
    for (let index = 0; index < screens.count; index += 1) {
        const screen = screens.objectAtIndex(index);
        const existing = workspace.desktopImageOptionsForScreen(screen);
        const options = existing ? existing.mutableCopy : $.NSMutableDictionary.dictionary;
        options.setObjectForKey($($.NSImageScaleAxesIndependently), $.NSWorkspaceDesktopImageScalingKey);
        const error = Ref();
        if (!workspace.setDesktopImageURLForScreenOptionsError(url, screen, options, error)) {
            throw new Error(error[0] ? ObjC.unwrap(error[0].localizedDescription) : "Could not set the desktop background");
        }
        const actual = workspace.desktopImageURLForScreen(screen);
        const scaling = workspace.desktopImageOptionsForScreen(screen).objectForKey($.NSWorkspaceDesktopImageScalingKey);
        if (ObjC.unwrap(actual.path) !== ObjC.unwrap(url.path) || Number(ObjC.unwrap(scaling)) !== Number($.NSImageScaleAxesIndependently)) {
            throw new Error("macOS did not apply the requested background and stretch-to-fill setting");
        }
    }
}`;

    return [
        {
            argv: ["/usr/bin/osascript", "-l", "JavaScript", "-e", script, image],
            message: "could not set the macOS desktop background and stretch-to-fill mode",
        },
    ];
}