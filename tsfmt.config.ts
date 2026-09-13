import {tsfmt} from "tsfmt";

export default tsfmt({
    paths: {
        exclude: [
            "**/*/node_modules/**",
            // "raycast/desktop-background/node_modules/**",
            // "raycast/desktop-background/dist/**",
        ],
    },
});