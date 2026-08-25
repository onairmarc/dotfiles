// provision/migrations/20250830_124630_move_sys_cleanup_marker.ts
//
// Migration: move sys_cleanup_marker
// Created: Sat Aug 30 12:46:30 CDT 2025
// Ported from: migrations/20250830_124630_move_sys_cleanup_marker.sh
//
// Copies $HOME/.df_sys_cleanup_marker to $HOME/.df_data/.sys_cleanup_marker
// (if the source exists), then removes the old location.
// Implements safe_copy semantics: no-op when source is absent.
import {readFileSync, rmSync, writeFileSync} from "node:fs";
import type {Migration} from "../lib/migrations.ts";
import * as platform from "../lib/platform.ts";

const migration: Migration = {
    name: "20250830_124630_move_sys_cleanup_marker",
    description: "Move .df_sys_cleanup_marker from $HOME into $HOME/.df_data/",
    up() {
        const home = platform.home();
        const oldPath = home + "/.df_sys_cleanup_marker";
        const newPath = home + "/.df_data/.sys_cleanup_marker";
        let content: Buffer;
        try {
            content = readFileSync(oldPath);
        } catch {
            return; // source absent — nothing to move
        }

        platform.mkdirP(home + "/.df_data");
        writeFileSync(newPath, content);
        try {
            rmSync(oldPath);
        } catch {
            // best-effort removal; ignore if already gone
        }
    },
};

export default migration;