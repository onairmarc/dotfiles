#!/bin/bash

#
# Copyright (c) 2025. Encore Digital Group.
# All Right Reserved.
#
# Migration Helper Functions
#

# Backup and move functions
backup_file() {
    local source="$1"
    local backup_dir="$DF_ROOT_DIRECTORY/.migrations/backups"
    
    if [ ! -f "$source" ]; then
        return 0
    fi
    
    mkdir -p "$backup_dir"
    local timestamp="$(date '+%Y%m%d_%H%M%S')"
    local backup_name="$(basename "$source").backup.$timestamp"
    local backup_path="$backup_dir/$backup_name"
    
    cp "$source" "$backup_path"
    log "Backed up '$source' to '$backup_path'"
}

safe_move() {
    local source="$1"
    local destination="$2"
    
    if [ ! -e "$source" ]; then
        return 0
    fi
    
    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$destination")"
    
    # Backup destination if it exists
    if [ -e "$destination" ]; then
        backup_file "$destination"
    fi
    
    mv "$source" "$destination"
    log "Moved '$source' to '$destination'"
}

safe_copy() {
    local source="$1"
    local destination="$2"
    
    if [ ! -e "$source" ]; then
        return 0
    fi
    
    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$destination")"
    
    # Backup destination if it exists
    if [ -e "$destination" ]; then
        backup_file "$destination"
    fi
    
    cp -r "$source" "$destination"
    log "Copied '$source' to '$destination'"
}

ensure_directory() {
    local directory="$1"
    
    if [ ! -d "$directory" ]; then
        mkdir -p "$directory"
        log "Created directory '$directory'"
    fi
}

remove_if_exists() {
    local target="$1"
    
    if [ -e "$target" ]; then
        backup_file "$target"
        rm -rf "$target"
        log "Removed '$target'"
    fi
}

# Configuration file helpers
update_config_line() {
    local file="$1"
    local pattern="$2"
    local replacement="$3"
    
    if [ ! -f "$file" ]; then
        log "Config file '$file' does not exist"
        return 1
    fi
    
    backup_file "$file"
    
    if grep -q "$pattern" "$file"; then
        sed -i '' "s|$pattern|$replacement|g" "$file"
        log "Updated pattern '$pattern' in '$file'"
    else
        echo "$replacement" >> "$file"
        log "Added new line '$replacement' to '$file'"
    fi
}

append_to_config() {
    local file="$1"
    local content="$2"
    
    # Create file if it doesn't exist
    touch "$file"
    
    # Check if content already exists
    if ! grep -Fq "$content" "$file"; then
        echo "$content" >> "$file"
        log "Appended content to '$file'"
    fi
}

remove_from_config() {
    local file="$1"
    local pattern="$2"
    
    if [ ! -f "$file" ]; then
        return 0
    fi
    
    backup_file "$file"
    sed -i '' "/$pattern/d" "$file"
    log "Removed lines matching '$pattern' from '$file'"
}

# Symlink helpers
create_symlink() {
    local target="$1"
    local link_path="$2"
    
    if [ ! -e "$target" ]; then
        log "Target '$target' does not exist, cannot create symlink"
        return 1
    fi
    
    # Remove existing link or file
    if [ -L "$link_path" ]; then
        rm "$link_path"
        log "Removed existing symlink '$link_path'"
    elif [ -e "$link_path" ]; then
        backup_file "$link_path"
        rm -rf "$link_path"
        log "Backed up and removed existing file/directory '$link_path'"
    fi
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$link_path")"
    
    ln -s "$target" "$link_path"
    log "Created symlink '$link_path' -> '$target'"
}

# Validation helpers
check_command_exists() {
    local command="$1"
    
    if ! command -v "$command" >/dev/null 2>&1; then
        log "WARNING: Command '$command' not found"
        return 1
    fi
    
    return 0
}

check_file_exists() {
    local file="$1"
    local required="${2:-false}"
    
    if [ ! -f "$file" ]; then
        if [ "$required" = "true" ]; then
            error "Required file '$file' does not exist"
        else
            return 1
        fi
    fi
    
    return 0
}

# OS detection helpers
is_macos() {
    [ "$OSTYPE" = "darwin"* ]
}

is_linux() {
    [ "$OSTYPE" = "linux-gnu"* ]
}

is_windows() {
    [ "$OSTYPE" = "msys" ] || [ "$OSTYPE" = "cygwin" ]
}

# Git helpers
git_clone_or_pull() {
    local repo_url="$1"
    local destination="$2"
    
    if [ -d "$destination/.git" ]; then
        log "Repository already exists at '$destination', pulling latest changes"
        (cd "$destination" && git pull)
    else
        log "Cloning repository '$repo_url' to '$destination'"
        git clone "$repo_url" "$destination"
    fi
}

# Package manager helpers
install_homebrew_package() {
    local package="$1"
    
    if ! is_macos; then
        return 0
    fi
    
    if ! check_command_exists "brew"; then
        log "Homebrew not installed, skipping package '$package'"
        return 1
    fi
    
    if brew list "$package" >/dev/null 2>&1; then
        return 0
    fi
    
    log "Installing Homebrew package '$package'"
    brew install "$package"
}

# Migration state helpers
set_migration_state() {
    local key="$1"
    local value="$2"
    local repo_context="${3:-dotfiles}"
    local state_file
    
    if [ "$repo_context" = "dotfiles-private" ] && [ -n "$DF_PRIVATE_DIRECTORY" ]; then
        state_file="$DF_PRIVATE_DIRECTORY/.migrations/.migration_state"
    else
        state_file="$DF_ROOT_DIRECTORY/.migrations/.migration_state"
    fi
    
    mkdir -p "$(dirname "$state_file")"
    
    # Remove existing key if it exists
    if [ -f "$state_file" ]; then
        grep -v "^$key=" "$state_file" > "$state_file.tmp" 2>/dev/null || true
        mv "$state_file.tmp" "$state_file"
    fi
    
    # Add new key-value pair
    echo "$key=$value" >> "$state_file"
    log "Set migration state for $repo_context: $key=$value"
}

get_migration_state() {
    local key="$1"
    local repo_context="${2:-dotfiles}"
    local state_file
    
    if [ "$repo_context" = "dotfiles-private" ] && [ -n "$DF_PRIVATE_DIRECTORY" ]; then
        state_file="$DF_PRIVATE_DIRECTORY/.migrations/.migration_state"
    else
        state_file="$DF_ROOT_DIRECTORY/.migrations/.migration_state"
    fi
    
    if [ ! -f "$state_file" ]; then
        return 1
    fi
    
    grep "^$key=" "$state_file" | cut -d'=' -f2- || return 1
}
