#!/bin/bash

#
# Copyright (c) 2025. Encore Digital Group.
# All Right Reserved.
#

# Migration system performance optimizations

# Cache file for migration metadata
DF_MIGRATION_CACHE="${DF_DATA_DIR}/migration_cache"

# Initialize migration cache directory
__df_init_migration_cache() {
    if [[ ! -d "$DF_DATA_DIR" ]]; then
        mkdir -p "$DF_DATA_DIR"
    fi
}

# Check if there are any migrations that might need to run
__df_has_pending_migrations() {
    # Quick check: if migrations directories don't exist, no migrations to run
    if [[ ! -d "$DF_ROOT_DIRECTORY/.migrations" ]]; then
        local has_private_migrations=false
        if [[ -n "$DF_PRIVATE_DIRECTORY" && -d "$DF_PRIVATE_DIRECTORY/.migrations" ]]; then
            has_private_migrations=true
        fi

        if [[ "$has_private_migrations" = false ]]; then
            return 1  # No pending migrations
        fi
    fi

    # Check cache file age (24 hours)
    if [[ -f "$DF_MIGRATION_CACHE" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$DF_MIGRATION_CACHE" 2>/dev/null || stat -f %m "$DF_MIGRATION_CACHE" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 86400 ]]; then
            local cache_result=$(cat "$DF_MIGRATION_CACHE" 2>/dev/null || echo "check")
            if [[ "$cache_result" = "none" ]]; then
                return 1  # Cache says no pending migrations
            fi
        fi
    fi

    # If we get here, we need to check for real
    return 0  # Might have pending migrations
}

# Update the migration cache
__df_update_migration_cache() {
    local has_pending="$1"
    __df_init_migration_cache

    if [[ "$has_pending" = "true" ]]; then
        echo "pending" > "$DF_MIGRATION_CACHE"
    else
        echo "none" > "$DF_MIGRATION_CACHE"
    fi
}

# Optimized migration runner
__df_run_migrations_optimized() {
    # Quick exit if no migrations could be pending
    if ! __df_has_pending_migrations; then
        return 0
    fi

    # Run the full migration check
    run_all_migrations

    # Cache the result - assume no more pending if we got here
    __df_update_migration_cache "false"
}