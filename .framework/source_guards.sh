#!/bin/bash



# Source guard utility functions to prevent duplicate sourcing
# and improve shell startup performance

# Function to check if a file has already been sourced
__df_is_already_sourced() {
    local file_identifier="$1"
    local guard_var="_SOURCED_${file_identifier}"

    # Check if the guard variable is set
    if [[ -n "${!guard_var}" ]]; then
        return 0  # Already sourced
    else
        return 1  # Not yet sourced
    fi
}

# Function to mark a file as sourced
__df_mark_as_sourced() {
    local file_identifier="$1"
    local guard_var="_SOURCED_${file_identifier}"

    # Set the guard variable
    export "${guard_var}"=1
}

# Wrapper function to source a file only if not already sourced
__df_source_once() {
    local file_path="$1"
    local file_identifier="${2:-$(basename "$file_path" .sh | tr '.' '_' | tr '-' '_')}"

    # Check if file exists
    if [[ ! -f "$file_path" ]]; then
        return 1
    fi

    # Check if already sourced
    if __df_is_already_sourced "$file_identifier"; then
        return 0
    fi

    # Source the file and mark as sourced
    source "$file_path"
    __df_mark_as_sourced "$file_identifier"
}

# Performance timing utilities for debugging
if [[ -n "$DF_DEBUG_TIMING" ]]; then
    _df_start_time=""

    __df_start_timing() {
        _df_start_time=$(date +%s%3N)
    }

    __df_end_timing() {
        local label="$1"
        if [[ -n "$_df_start_time" ]]; then
            local end_time=$(date +%s%3N)
            local duration=$((end_time - _df_start_time))
            echo "[TIMING] $label: ${duration}ms" >&2
        fi
    }

    # Enhanced source_once with timing
    __df_source_once_timed() {
        local file_path="$1"
        local file_identifier="${2:-$(basename "$file_path" .sh | tr '.' '_' | tr '-' '_')}"

        if __df_is_already_sourced "$file_identifier"; then
            echo "[TIMING] $file_identifier: 0ms (already sourced)" >&2
            return 0
        fi

        __df_start_timing
        __df_source_once "$file_path" "$file_identifier"
        __df_end_timing "$file_identifier"
    }
else
    # No-op functions when timing is disabled
    __df_start_timing() { :; }
    __df_end_timing() { :; }
    __df_source_once_timed() { __df_source_once "$@"; }
fi