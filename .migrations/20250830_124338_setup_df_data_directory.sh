#!/bin/bash

#
# Migration: setup df_data directory
# Created: Sat Aug 30 12:43:38 CDT 2025
#

set -e

# Add your migration logic here
# Example:
# mv "$DF_CONFIG_DIRECTORY/old_config" "$DF_CONFIG_DIRECTORY/new_config"
# mkdir -p "$DF_TOOLS_DIRECTORY/new_directory"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MIGRATION: $1"
}

log "Starting migration: setup df_data directory"

mkdir "$HOME/.df_data"
mkdir "$HOME/.df_data/tokens"
touch "$HOME/.df_data/.sys_cleanup_marker"

log "Migration completed: setup df_data directory"
