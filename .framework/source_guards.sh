#!/bin/bash

# Source guard utility functions to prevent duplicate sourcing
# and improve shell startup performance

# Function to check if a file has already been sourced
__df_get_var_value() {
    # Return the value of a variable whose name is passed in $1 in a portable way
    local name="$1"

    # Bash supports ${!name}
    if [[ -n "${BASH_VERSION-}" ]]; then
        printf '%s' "${!name}"
        return
    fi

    # For other shells (including zsh and POSIX sh), use eval fallback
    # Eval is safe here because callers only pass sanitized variable names
    # Use "$<varname>" form inside eval (e.g. "$FOO") to avoid nested ${${x}} syntax
    eval "printf '%s' \"\$$name\""
}

# Function to check if a file has already been sourced
__df_is_already_sourced() {
    local file_identifier="$1"
    local guard_var="_SOURCED_${file_identifier}"

    # Get the value of the guard variable in a portable way
    local val
    val="$(__df_get_var_value "$guard_var")"

    # Check if the guard variable is set
    if [[ -n "$val" ]]; then
        return 0  # Already sourced
    else
        return 1  # Not yet sourced
    fi
}

# Function to mark a file as sourced
__df_mark_as_sourced() {
    local file_identifier="$1"
    local guard_var="_SOURCED_${file_identifier}"

    # Set the guard variable in a portable way and export it so child processes see it if needed
    # We use eval to assign to a dynamic name. The identifiers are generated with tr to
    # replace non-safe characters, so this is acceptable here.
    eval "export ${guard_var}=1"
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
    # shellcheck disable=SC1090
    source "$file_path"
    __df_mark_as_sourced "$file_identifier"
}

# Portable timing function for cross-platform compatibility
__df_get_timestamp_ms() {
    # Attempt to use nanoseconds if supported. On BSD/macOS `date +%N` prints a literal 'N'.
    # We'll detect that and fall back to seconds*1000.
    local ns
    ns=$(date +%N 2>/dev/null) || ns=""

    local ts
    case "$ns" in
        # empty or non-numeric (including literal 'N') -> fallback
        ''|*[!0-9]*)
            ts=$(( $(date +%s) * 1000 ))
            ;;
        *)
            # numeric nanoseconds available
            local s
            s=$(date +%s)
            local ms_from_ns=$((ns / 1000000))
            ts=$((s * 1000 + ms_from_ns))
            ;;
    esac

    # Ensure the returned value is numeric; coerce to 0 if not (defensive)
    case "$ts" in
        ''|*[!0-9]*) ts=0 ;;
    esac

    printf '%s' "$ts"
}

# Performance timing utilities for debugging
if [[ -n "$DF_DEBUG_TIMING" ]]; then
    _df_start_time=""

    __df_start_timing() {
        _df_start_time=$(__df_get_timestamp_ms)
    }

    __df_end_timing() {
        local label="$1"
        if [[ -n "$_df_start_time" ]]; then
            local end_time
            end_time=$(__df_get_timestamp_ms)
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
    __df_get_timestamp_ms() { :; }
    __df_start_timing() { :; }
    __df_end_timing() { :; }
    __df_source_once_timed() { __df_source_once "$@"; }
fi