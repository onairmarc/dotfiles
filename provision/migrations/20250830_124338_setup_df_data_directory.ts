// provision/migrations/20250830_124338_setup_df_data_directory.ts
//
// Migration: setup df_data directory
// Created: Sat Aug 30 12:43:38 CDT 2025
// Ported from: migrations/20250830_124338_setup_df_data_directory.sh
//
// Creates ~/.df_data/, ~/.df_data/tokens/, and ~/.df_data/.sys_cleanup_marker.
// Idempotent: recursive mkdir and marker touch are no-ops when targets exist.
import {closeSync, openSync} from "node:fs";
import type {Migration} from "../lib/migrations.ts";
import * as platform from "../lib/platform.ts";

const migration: Migration = {
    name: "20250830_124338_setup_df_data_directory",
    description: "Create the ~/.df_data directory structure",
    up() {
        const dataDir = platform.dataDir();
        platform.mkdirP(dataDir);
        platform.mkdirP(dataDir + "/tokens");

        // Create the cleanup marker file if absent. "a" opens for append, creating
        // the file if it does not exist without truncating an existing one.
        const marker = dataDir + "/.sys_cleanup_marker";
        const fd = openSync(marker, "a");
        closeSync(fd);
    },
};

export default migration;