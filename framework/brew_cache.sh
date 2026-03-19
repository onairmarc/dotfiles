#!/bin/bash

# Brew prefix caching system to avoid expensive $(brew --prefix) calls

# Cache file location using DF_DATA_DIR
DF_BREW_PREFIX_CACHE="${DF_DATA_DIR}/brew_prefix"

# Initialize cache directory
__df_init_brew_cache() {
    if [[ ! -d "$DF_DATA_DIR" ]]; then
        mkdir -p "$DF_DATA_DIR"
    fi
}

# Get cached brew prefix or compute and cache it
__df_get_brew_prefix() {
    # Check if cache exists and is recent (less than 24 hours old)
    if [[ -f "$DF_BREW_PREFIX_CACHE" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$DF_BREW_PREFIX_CACHE" 2>/dev/null || stat -f %m "$DF_BREW_PREFIX_CACHE" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 86400 ]]; then # 24 hours
            cat "$DF_BREW_PREFIX_CACHE"
            return 0
        fi
    fi

    # Cache is old or doesn't exist, compute brew prefix
    if command -v brew >/dev/null 2>&1; then
        __df_init_brew_cache
        local brew_prefix
        brew_prefix=$(brew --prefix)
        if [[ -n "$brew_prefix" ]]; then
            echo "$brew_prefix" > "$DF_BREW_PREFIX_CACHE"
            echo "$brew_prefix"
            return 0
        fi
    fi

    # Fallback if brew is not available
    echo ""
    return 1
}

# Clear brew cache (useful for testing or when brew location changes)
__df_clear_brew_cache() {
    rm -f "$DF_BREW_PREFIX_CACHE"
}