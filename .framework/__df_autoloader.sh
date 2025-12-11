#!/usr/bin/env bash

# Portable timing function for cross-platform compatibility
__df_get_timestamp_ms() {
    if date +%N >/dev/null 2>&1; then
        # GNU date (Linux) - supports nanoseconds
        date +%s%3N
    else
        # BSD date (macOS) - fallback to seconds * 1000
        echo $(($(date +%s) * 1000))
    fi
}

# Start timing for debug mode
if [[ -n "$DF_DEBUG_TIMING" ]]; then
    _autoloader_start_time=$(__df_get_timestamp_ms)
fi

ensure_autoloader() {
  if [[ -z "$DF_AUTOLOADER_SOURCED" && -f "$DF_ROOT_DIRECTORY/.framework/__df_autoloader.sh" ]]; then
      source "$DF_ROOT_DIRECTORY/.framework/__df_autoloader.sh"
      export DF_AUTOLOADER_SOURCED=1
  fi
}

# Root DotFiles Directory Env
export DF_ROOT_DIRECTORY="$HOME/Documents/GitHub/dotfiles"

# Data Directory Env (for caches, logs, etc.)
export DF_DATA_DIR="${DF_DATA_DIR:-$HOME/.df_data}"

# Performance debugging env var
# Set DF_DEBUG_TIMING=1 to enable detailed timing output
export DF_DEBUG_TIMING="${DF_DEBUG_TIMING:-}"

# Module Specific Directory Envs
export DF_AUTOLOADER_DIRECTORY="$DF_ROOT_DIRECTORY/.autoloader"
export DF_CONFIG_DIRECTORY="$DF_ROOT_DIRECTORY/.config"
export DF_TOOLS_DIRECTORY="$DF_ROOT_DIRECTORY/.tools"

# Load source guards first
if [ -f "$DF_ROOT_DIRECTORY/.framework/source_guards.sh" ]; then
    source "$DF_ROOT_DIRECTORY/.framework/source_guards.sh"
fi

# Load framework components with source guards
__df_source_once "$DF_ROOT_DIRECTORY/.framework/brew_cache.sh" "brew_cache"
__df_source_once "$DF_ROOT_DIRECTORY/.framework/migrations/migrate.sh" "migrate"
__df_source_once "$DF_ROOT_DIRECTORY/.framework/migrations/migration_helpers.sh" "migration_helpers"
__df_source_once "$DF_ROOT_DIRECTORY/.framework/migration_optimizer.sh" "migration_optimizer"
__df_source_once "$DF_ROOT_DIRECTORY/.framework/logging_functions.sh" "logging_functions"

# End timing for debug mode
if [[ -n "$DF_DEBUG_TIMING" ]]; then
    _autoloader_end_time=$(__df_get_timestamp_ms)
    echo "[TIMING] autoloader.sh: $((_autoloader_end_time - _autoloader_start_time))ms" >&2
fi
