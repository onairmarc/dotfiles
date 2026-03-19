#!/bin/bash

#
# Migration: move sys_cleanup_marker
# Created: Sat Aug 30 12:46:30 CDT 2025
#

set -e

# Add your migration logic here
# Example:
# mv "$DF_CONFIG_DIRECTORY/old_config" "$DF_CONFIG_DIRECTORY/new_config"
# mkdir -p "$DF_TOOLS_DIRECTORY/new_directory"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MIGRATION: $1"
}

log "Starting migration: move sys_cleanup_marker"

safe_copy "$HOME/.df_sys_cleanup_marker" "$HOME/.df_data/.sys_cleanup_marker"
rm -f "$HOME/.df_sys_cleanup_marker"

log "Migration completed: move sys_cleanup_marker"
