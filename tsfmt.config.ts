import {tsfmt} from "tsfmt";

export default tsfmt({
    paths: {
        exclude: [
            "raycast/desktop-background/node_modules/**",
            "raycast/desktop-background/dist/**",
        ],
    },
});