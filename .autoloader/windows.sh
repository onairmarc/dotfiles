#!/usr/bin/env bash

# Start timing for debug mode
if [[ -n "$DF_DEBUG_TIMING" ]]; then
    _windows_autoloader_start_time=$(__df_get_timestamp_ms)
fi

# Load Configurations (Ordering Matters)
__df_source_once "$DF_CONFIG_DIRECTORY/env.sh" "env"
__df_source_once "$DF_CONFIG_DIRECTORY/color.sh" "color"
__df_source_once "$DF_CONFIG_DIRECTORY/alias.sh" "alias"
__df_source_once "$DF_CONFIG_DIRECTORY/func.sh" "func"

# Load Tool Configurations (Sorted Alphabetically)
__df_source_once "$DF_TOOLS_DIRECTORY/aws.sh" "aws"
__df_source_once "$DF_TOOLS_DIRECTORY/docker.sh" "docker"

# Conditionally Load Entrypoint to Private DotFiles
DF_PRIVATE_DIRECTORY="$HOME/Documents/GitHub/dotfiles-private"
[ -f "$DF_PRIVATE_DIRECTORY/entrypoint.sh" ] && source "$DF_PRIVATE_DIRECTORY/entrypoint.sh"

# End timing for debug mode
if [[ -n "$DF_DEBUG_TIMING" ]]; then
    _windows_autoloader_end_time=$(__df_get_timestamp_ms)
    echo "[TIMING] windows autoloader: $((_windows_autoloader_end_time - _windows_autoloader_start_time))ms" >&2
fi