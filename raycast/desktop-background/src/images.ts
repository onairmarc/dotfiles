import {readdir} from "node:fs/promises";
import {join} from "node:path";

const IMAGE_EXTENSION = /\.(?:avif|bmp|gif|jpe?g|png|tiff?|webp)$/i;

export async function listImages(directory: string): Promise<string[]> {
    const entries = await readdir(directory, {withFileTypes: true});
    const images = entries
        .filter((entry) => entry.isFile() && IMAGE_EXTENSION.test(entry.name))
        .map((entry) => entry.name)
        .sort()
        .map((name) => join(directory, name));

    if (images.length === 0) {
        throw new Error(`No supported images found in ${directory}`);
    }

    return images;
}

export function selectImage(images: string[], current: string, direction: 1 | -1): string {
    if (images.length === 0) {
        throw new Error("No backgrounds available");
    }

    const index = images.indexOf(current);
    if (index === -1) {
        return direction === 1 ? images[0] : images[images.length - 1];
    }

    return images[(index + direction + images.length) % images.length];
}