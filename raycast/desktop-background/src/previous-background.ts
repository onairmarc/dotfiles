import {rotateBackground} from "./rotate-background";

export default async function Command(): Promise<void> {
    await rotateBackground(-1);
}
