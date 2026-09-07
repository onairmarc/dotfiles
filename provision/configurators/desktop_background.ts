// provision/configurators/desktop_background.ts
//
// Sets the preferred bundled image as the user's desktop background, falling
// back to a random supported image when it is unavailable. The image stretches
// to fill each screen.
import {readdirSync} from "node:fs";
import {join} from "node:path";
import * as platform from "../lib/platform.ts";
import {powershell, runAssert} from "../lib/shell.ts";

const IMAGE_EXTENSION = /\.(?:avif|bmp|gif|jpe?g|png|tiff?|webp)$/i;

const PREFERRED_IMAGE = "LaravelLego.png";

function selectImage(): string {
    const backgroundsDir = join(platform.dotfilesRoot(), "backgrounds");
    const images = readdirSync(backgroundsDir, {withFileTypes: true})
        .filter((entry) => entry.isFile() && IMAGE_EXTENSION.test(entry.name))
        .map((entry) => join(backgroundsDir, entry.name));

    if (images.length === 0) {
        throw new Error(`no supported images found in ${backgroundsDir}`);
    }

    const preferredImage = join(backgroundsDir, PREFERRED_IMAGE);
    if (images.includes(preferredImage)) {
        return preferredImage;
    }

    return images[Math.floor(Math.random() * images.length)];
}

function setMacBackground(image: string): void {
    const script = `on run argv
    tell application "System Events"
        tell every desktop
            set picture to (POSIX file (item 1 of argv))
        end tell
    end tell
end run`;

    runAssert(["/usr/bin/osascript", "-e", script, image], "could not set the macOS desktop background");

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

    runAssert(
        ["/usr/bin/osascript", "-l", "JavaScript", "-e", placementScript],
        "could not set the macOS wallpaper display mode",
    );
    runAssert(["/usr/bin/killall", "WallpaperAgent"], "could not reload the macOS wallpaper settings");
}

function setWindowsBackground(image: string): void {
    const escapedImage = image.replaceAll("'", "''");
    const command = `$signature = @'
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
public static extern bool SystemParametersInfoW(uint action, uint param, string value, uint flags);
'@
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "2"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value "0"
$wallpaper = Add-Type -MemberDefinition $signature -Name Wallpaper -Namespace Dotfiles -PassThru
if (-not $wallpaper::SystemParametersInfoW(20, 0, '${escapedImage}', 3)) {
    throw "Could not set the Windows desktop background. Win32 error: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
}`;

    if (!powershell(command)) {
        throw new Error("could not set the Windows desktop background");
    }
}

export function run(): void {
    const image = selectImage();

    if (platform.isMac()) {
        setMacBackground(image);
    } else {
        setWindowsBackground(image);
    }
}
