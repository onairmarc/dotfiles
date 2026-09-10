// Shared argv commands for provisioning and the local Raycast extension.
// Keep image paths as arguments rather than interpolating them into AppleScript.
export function macBackgroundCommands(image: string): {argv: string[]; message: string}[] {
    const script = `on run argv
    tell application "System Events"
        tell every desktop
            set picture to (POSIX file (item 1 of argv))
        end tell
    end tell
end run`;

    const placementScript = `ObjC.import("Foundation");
const home = ObjC.unwrap($.NSProcessInfo.processInfo.environment.objectForKey("HOME"));
const path = home + "/Library/Application Support/com.apple.wallpaper/Store/Index.plist";
const data = $.NSData.dataWithContentsOfFile($(path));
function encodedPlacement() {
    const selected = $.NSMutableDictionary.dictionary;
    const picker = $.NSMutableDictionary.dictionary;
    const placement = $.NSMutableDictionary.dictionary;
    const values = $.NSMutableDictionary.dictionary;
    const options = $.NSMutableDictionary.dictionary;
    selected.setObjectForKey($("StretchToFillScreen"), $("id"));
    picker.setObjectForKey(selected, $("_0"));
    placement.setObjectForKey(picker, $("picker"));
    values.setObjectForKey(placement, $("placement"));
    options.setObjectForKey(values, $("values"));
    return $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(options, 200, 0, null);
}
function setPlacement(node) {
    const copy = node.mutableCopy;
    const desktop = copy.objectForKey($("Desktop"));
    if (desktop && typeof desktop.objectForKey === "function") {
        const desktopCopy = desktop.mutableCopy;
        const content = desktopCopy.objectForKey($("Content")).mutableCopy;
        content.setObjectForKey(encodedPlacement(), $("EncodedOptionValues"));
        desktopCopy.setObjectForKey(content, $("Content"));
        copy.setObjectForKey(desktopCopy, $("Desktop"));
    }
    const keys = copy.allKeys;
    for (let index = 0; index < keys.count; index += 1) {
        const key = keys.objectAtIndex(index);
        const value = copy.objectForKey(key);
        if (value && typeof value.objectForKey === "function") {
            copy.setObjectForKey(setPlacement(value), key);
        }
    }
    return copy;
}
const source = $.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(data, 0, null, null);
const root = setPlacement(source);
if (!root.writeToFileAtomically($(path), true)) {
    throw new Error("could not save the macOS wallpaper settings");
}`;

    return [
        {argv: ["/usr/bin/osascript", "-e", script, image], message: "could not set the macOS desktop background"},
        {
            argv: ["/usr/bin/osascript", "-l", "JavaScript", "-e", placementScript],
            message: "could not set the macOS wallpaper display mode",
        },
        {argv: ["/usr/bin/killall", "WallpaperAgent"], message: "could not reload the macOS wallpaper settings"},
    ];
}
