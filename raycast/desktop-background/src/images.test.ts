import {describe, expect, test} from "bun:test";
import {fileURLToPath} from "node:url";
import {listImages, selectImage} from "./images.ts";

describe("background rotation", () => {
    const images = ["/images/a.png", "/images/b.jpg", "/images/c.webp"];
    test("moves in both directions and wraps at either end", () => {
        expect(selectImage(images, images[0], 1)).toBe(images[1]);
        expect(selectImage(images, images[2], 1)).toBe(images[0]);
        expect(selectImage(images, images[2], -1)).toBe(images[1]);
        expect(selectImage(images, images[0], -1)).toBe(images[2]);
    });

    test("starts at the appropriate end when the current image is outside the collection", () => {
        expect(selectImage(images, "/other/wallpaper.png", 1)).toBe(images[0]);
        expect(selectImage(images, "/other/wallpaper.png", -1)).toBe(images[2]);
    });

    test("handles a single image and rejects an empty collection", () => {
        expect(selectImage([images[0]], images[0], -1)).toBe(images[0]);
        expect(() => selectImage([], "", 1)).toThrow("No backgrounds available");
    });

    test("discovers the actual bundled backgrounds in filename order", async () => {
        const directory = fileURLToPath(new URL("../../../backgrounds/", import.meta.url));
        const found = await listImages(directory);
        expect(found.length).toBeGreaterThan(0);
        expect(found).toEqual([...found].sort());
        expect(found).toContain(`${directory}LaravelLego.png`);
    });

    test("reports a directory without images", async () => {
        const directory = fileURLToPath(new URL("../src/", import.meta.url));
        expect(listImages(directory)).rejects.toThrow("No supported images found");
    });
});