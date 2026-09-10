// provision/configurators/desktop_background.ts
//
// Sets the preferred bundled image as the user's desktop background, falling
// back to a random supported image when it is unavailable. The image stretches
// to fill each screen.
import {readdirSync} from "node:fs";
import {join} from "node:path";
import {macBackgroundCommands} from "../lib/mac_background.ts";
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
    for (const {argv, message} of macBackgroundCommands(image)) {
        runAssert(argv, message);
    }
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
