#!/bin/bash

#
# Copyright (c) 2025. Encore Digital Group.
# All Right Reserved.
#

MIGRATIONS_DIR="$DF_ROOT_DIRECTORY/.migrations"
MIGRATIONS_LOG="$MIGRATIONS_DIR/.migration_history"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

init_migration_tracking() {
    if [ ! -f "$MIGRATIONS_LOG" ]; then
        touch "$MIGRATIONS_LOG"
    fi
}

is_migration_completed() {
    local migration_name="$1"
    grep -q "^$migration_name$" "$MIGRATIONS_LOG" 2>/dev/null
}

is_migration_completed_for_repo() {
    local migration_name="$1"
    local log_file="$2"
    grep -q "^$migration_name$" "$log_file" 2>/dev/null
}

mark_migration_completed() {
    local migration_name="$1"
    echo "$migration_name" >> "$MIGRATIONS_LOG"
}

mark_migration_completed_for_repo() {
    local migration_name="$1"
    local log_file="$2"
    local repo_name="$3"
    echo "$migration_name" >> "$log_file"
}

run_migration() {
    local migration_file="$1"
    local migration_name="$(basename "$migration_file" .sh)"
    
    if is_migration_completed "$migration_name"; then
        return 0
    fi
    
    log "Running migration: $migration_name"
    
    if [ ! -x "$migration_file" ]; then
        error "Migration file '$migration_file' is not executable"
        return 1
    fi
    
    # Source the migration file
    if ! "$migration_file"; then
        error "Migration '$migration_name' failed"
        return 1
    fi
    
    mark_migration_completed "$migration_name"
    log "Migration '$migration_name' completed successfully"
}

run_migration_for_repo() {
    local migration_file="$1"
    local log_file="$2"
    local repo_name="$3"
    local migration_name="$(basename "$migration_file" .sh)"
    
    if is_migration_completed_for_repo "$migration_name" "$log_file"; then
        return 0
    fi
    
    log "Running migration for $repo_name: $migration_name"
    
    if [ ! -x "$migration_file" ]; then
        error "Migration file '$migration_file' is not executable"
        return 1
    fi
    
    # Source the migration file
    if ! "$migration_file"; then
        error "Migration '$migration_name' failed for $repo_name"
        return 1
    fi
    
    mark_migration_completed_for_repo "$migration_name" "$log_file" "$repo_name"
    log "Migration '$migration_name' completed successfully for $repo_name"
}

run_migrations_for_directory() {
    local migrations_dir="$1"
    local log_file="$2"
    local repo_name="${3:-dotfiles}"
    local migrations_ran=false
    
    if [ ! -d "$migrations_dir" ]; then
        return 0
    fi
    
    # Initialize tracking for this repository
    if [ ! -f "$log_file" ]; then
        touch "$log_file"
    fi
    
    # Find all migration files and sort them
    local migration_files=()
    while IFS= read -r -d $'\0' file; do
        migration_files+=("$file")
    done < <(find "$migrations_dir" -maxdepth 1 -name "[0-9]*_*.sh" -print0 | sort -z)
    
    if [ ${#migration_files[@]} -eq 0 ]; then
        return 0
    fi
    
    # Check if any migrations need to run
    for migration_file in "${migration_files[@]}"; do
        local migration_name="$(basename "$migration_file" .sh)"
        if ! is_migration_completed_for_repo "$migration_name" "$log_file"; then
            migrations_ran=true
            break
        fi
    done
    
    # Only show start message if migrations will actually run
    if [ "$migrations_ran" = "true" ]; then
        log "Running $repo_name migrations..."
    fi
    
    for migration_file in "${migration_files[@]}"; do
        if ! run_migration_for_repo "$migration_file" "$log_file" "$repo_name"; then
            error "Migration $(basename "$migration_file" .sh) failed, but continuing with remaining migrations"
        fi
    done
    
    # Only show completion message if migrations actually ran
    if [ "$migrations_ran" = "true" ]; then
        log "All migrations completed for $repo_name"
    fi
}

run_all_migrations() {
    init_migration_tracking
    
    # Track if any migrations will run
    local any_migrations_pending=false
    
    # Check dotfiles migrations
    if [ -d "$MIGRATIONS_DIR" ]; then
        local migration_files=()
        while IFS= read -r -d $'\0' file; do
            migration_files+=("$file")
        done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -name "[0-9]*_*.sh" -print0 | sort -z)
        
        for migration_file in "${migration_files[@]}"; do
            local migration_name="$(basename "$migration_file" .sh)"
            if ! is_migration_completed "$migration_name"; then
                any_migrations_pending=true
                break
            fi
        done
    fi
    
    # Check dotfiles-private migrations if available
    if [ -n "$DF_PRIVATE_ROOT_DIRECTORY" ] && [ -d "$DF_PRIVATE_ROOT_DIRECTORY" ]; then
        local private_migrations_dir="$DF_PRIVATE_ROOT_DIRECTORY/.migrations"
        local private_log_file="$private_migrations_dir/.migration_history"
        
        if [ -d "$private_migrations_dir" ]; then
            local private_migration_files=()
            while IFS= read -r -d $'\0' file; do
                private_migration_files+=("$file")
            done < <(find "$private_migrations_dir" -maxdepth 1 -name "[0-9]*_*.sh" -print0 | sort -z)
            
            for migration_file in "${private_migration_files[@]}"; do
                local migration_name="$(basename "$migration_file" .sh)"
                if ! is_migration_completed_for_repo "$migration_name" "$private_log_file"; then
                    any_migrations_pending=true
                    break
                fi
            done
        fi
    fi
    
    # Only show start message if migrations will actually run
    if [ "$any_migrations_pending" = "true" ]; then
        log "Starting migration process"
    fi
    
    # Run dotfiles migrations first
    run_migrations_for_directory "$MIGRATIONS_DIR" "$MIGRATIONS_LOG" "dotfiles"
    
    # Check if dotfiles-private plugin is available and run its migrations
    if [ -n "$DF_PRIVATE_ROOT_DIRECTORY" ] && [ -d "$DF_PRIVATE_ROOT_DIRECTORY" ]; then
        local private_migrations_dir="$DF_PRIVATE_ROOT_DIRECTORY/.migrations"
        local private_log_file="$private_migrations_dir/.migration_history"
        
        run_migrations_for_directory "$private_migrations_dir" "$private_log_file" "dotfiles-private"
    fi
    
    # Only show completion message if migrations actually ran
    if [ "$any_migrations_pending" = "true" ]; then
        log "All migrations completed"
    fi
}

create_migration() {
    local description="$1"
    if [ -z "$description" ]; then
        error "Migration description is required"
    fi
    
    # Detect which repository we're in
    local current_dir="$(pwd)"
    local migrations_dir=""
    local repo_name=""
    local template_comment=""
    local template_examples=""
    
    if [ "$current_dir" = "$DF_ROOT_DIRECTORY" ]; then
        migrations_dir="$MIGRATIONS_DIR"
        repo_name="dotfiles"
        template_comment="# Migration: DESCRIPTION_PLACEHOLDER
# Created: TIMESTAMP_PLACEHOLDER
#"
        template_examples="# mv \"\$DF_CONFIG_DIRECTORY/old_config\" \"\$DF_CONFIG_DIRECTORY/new_config\"
# mkdir -p \"\$DF_TOOLS_DIRECTORY/new_directory\""
    elif [ -n "$DF_PRIVATE_DIRECTORY" ] && [ "$current_dir" = "$DF_PRIVATE_DIRECTORY" ]; then
        migrations_dir="$DF_PRIVATE_DIRECTORY/.migrations"
        repo_name="dotfiles-private"
        template_comment="# Migration: DESCRIPTION_PLACEHOLDER
# Created: TIMESTAMP_PLACEHOLDER
# Repository: dotfiles-private
#"
        template_examples="# mv \"\$DF_PRIVATE_CONFIG_DIRECTORY/old_config\" \"\$DF_PRIVATE_CONFIG_DIRECTORY/new_config\"
# mkdir -p \"\$DF_PRIVATE_TOOLS_DIRECTORY/new_directory\""
    else
        error "Must be in the root directory of either dotfiles or dotfiles-private repository to create migrations"
    fi
    
    # Ensure migrations directory exists
    mkdir -p "$migrations_dir"
    
    local timestamp="$(date '+%Y%m%d_%H%M%S')"
    local snake_case_description="$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')"
    local migration_name="${timestamp}_${snake_case_description}"
    local migration_file="$migrations_dir/${migration_name}.sh"
    
    cat > "$migration_file" << EOF
#!/bin/bash

#
$template_comment

set -e

# Add your migration logic here
# Example:
$template_examples

log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] MIGRATION: \$1"
}

log "Starting migration: $description"

# Your migration code goes here

log "Migration completed: $description"
EOF
    
    chmod +x "$migration_file"
    
    log "Created migration: $migration_file"
    echo "$migration_file"
}

rollback_migration() {
    local migration_name="$1"
    if [ -z "$migration_name" ]; then
        error "Migration name is required for rollback"
    fi
    
    if ! is_migration_completed "$migration_name"; then
        log "Migration '$migration_name' is not in completed state"
        return 0
    fi
    
    # Remove from migration history
    if grep -v "^$migration_name$" "$MIGRATIONS_LOG" > "$MIGRATIONS_LOG.tmp"; then
        mv "$MIGRATIONS_LOG.tmp" "$MIGRATIONS_LOG"
        log "Rolled back migration: $migration_name"
    else
        rm -f "$MIGRATIONS_LOG.tmp"
        error "Failed to rollback migration: $migration_name"
    fi
}

show_status_for_repo() {
    local migrations_dir="$1"
    local log_file="$2"
    local repo_name="$3"
    
    echo ""
    echo "=== $repo_name Migrations ==="
    
    if [ ! -d "$migrations_dir" ]; then
        echo "No migrations directory found"
        return 0
    fi
    
    local migration_files=()
    while IFS= read -r -d $'\0' file; do
        migration_files+=("$file")
    done < <(find "$migrations_dir" -maxdepth 1 -name "[0-9]*_*.sh" -print0 | sort -z)
    
    if [ ${#migration_files[@]} -eq 0 ]; then
        echo "No migrations found"
        return 0
    fi
    
    for migration_file in "${migration_files[@]}"; do
        local migration_name="$(basename "$migration_file" .sh)"
        if is_migration_completed_for_repo "$migration_name" "$log_file"; then
            echo "✓ $migration_name (completed)"
        else
            echo "✗ $migration_name (pending)"
        fi
    done
}

show_status() {
    log "Migration Status:"
    echo "===================="
    
    # Show dotfiles status
    init_migration_tracking
    show_status_for_repo "$MIGRATIONS_DIR" "$MIGRATIONS_LOG" "dotfiles"
    
    # Show dotfiles-private status if available
    if [ -n "$DF_PRIVATE_ROOT_DIRECTORY" ] && [ -d "$DF_PRIVATE_ROOT_DIRECTORY" ]; then
        local private_migrations_dir="$DF_PRIVATE_ROOT_DIRECTORY/.migrations"
        local private_log_file="$private_migrations_dir/.migration_history"
        show_status_for_repo "$private_migrations_dir" "$private_log_file" "dotfiles-private"
    fi
}