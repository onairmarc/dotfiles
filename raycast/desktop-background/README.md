# Dotfiles backgrounds for Raycast

Local macOS extension with two commands: **Next Background** and **Previous Background**. Assign hotkeys to change wallpaper without opening a picker.

## Install locally

Running `bash install.sh` from the repository root installs the extension during the macOS scripts phase. Setup installs Node.js and Raycast through Homebrew
on Apple Silicon, installs the extension's locked dependencies, and builds and refreshes the local extension. On Intel Macs, install Node.js and Raycast first,
following the repository's existing policy of skipping Homebrew there. Rerunning setup updates the extension without leaving a development watcher running.

To install or update only this extension, run from the repository root:

```sh
bun provision/scripts/raycast_backgrounds.ts
```

The installer honors `DF_ROOT_DIRECTORY`. Sign in to Raycast and finish its first-launch setup if needed, then assign hotkeys as described below.

For manual installation:

1. Install Raycast, Node.js 22.14 or later, and Bun. Sign in to Raycast for local extension development.
2. From this directory, run:

   ```sh
   bun install
   bun run install-local
   ```

3. Wait for the build to finish. The commands are installed locally and remain available after the process exits.
4. Open **Raycast Settings → Extensions → Dotfiles Backgrounds** and assign hotkeys, for example:
   - **Next Background:** ⌃⌥⌘→
   - **Previous Background:** ⌃⌥⌘←
5. Run either command. If macOS asks, allow Raycast to control **System Events**. This permission is under
   **System Settings → Privacy & Security → Automation**.

This is a local, unpublished extension. No Raycast team subscription or Store publication is needed. `private: true` prevents npm publication;
local installation is what keeps it out of the Raycast Store.

## Images and behavior

- Defaults to `~/Documents/GitHub/dotfiles/backgrounds`. For another checkout location, set **Backgrounds directory** in the extension's preferences.
  Raycast doesn't depend on your shell's `DF_ROOT_DIRECTORY` setting.
- Reads the directory on every invocation, so adding or removing images doesn't require a rebuild.
- Uses filename order and wraps around at either end. The bundled order is `LaravelLambo.jpeg` → `LaravelLego.png` → `LaravelThreeDee.png`.
- Reads the first desktop's current wallpaper to choose the next image. If it isn't in the directory, Next starts at the first image and Previous at the last.
- Applies the image to every desktop exposed by System Events and stretches it to fill, using the same commands as the provisioner.
- Supports the same file extensions as provisioning: AVIF, BMP, GIF, JPEG, PNG, TIFF, and WebP. macOS must be able to decode the chosen image.
- Shows a short confirmation or error message. No browser, image picker, or background timer is involved.

The stretch setting uses macOS's `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` and restarts `WallpaperAgent`, matching provisioning.

## Development

Keep this extension inside the dotfiles checkout: it imports `provision/lib/mac_background.ts`. Raycast bundles that shared module during the build.
Run `bun run install-local` after source changes to update the locally installed extension, or `bun run dev` to rebuild automatically while editing.
`bun run build` writes a validation build to `dist/` without updating the installed extension.

```sh
bun run build
bun run typecheck
bun run test
```

To check the installed integration, invoke Next through all three images, then Previous. Confirm wraparound, stretch-to-fill, and each connected display.
