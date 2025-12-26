#!/bin/bash

# JetBrains Keymap Copy Script
# Copies keymaps from the dotfiles repository to platform-specific JetBrains directories

# Ensure autoloader is available
if [[ -z "$DF_ROOT_DIRECTORY" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    export DF_ROOT_DIRECTORY="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# Source autoloader if not already sourced
if [[ -z "$DF_AUTOLOADER_SOURCED" ]]; then
    source "$DF_ROOT_DIRECTORY/.framework/__df_autoloader.sh"
fi

# Define supported IDEs
IDES=("GoLand" "PhpStorm" "WebStorm" "IntelliJIdea" "Rider" "PyCharm" "CLion" "RubyMine" "DataGrip" "AndroidStudio")

# Set the dotfiles repository keymap source (fixed path)
KEYMAP_SOURCE="$DF_ROOT_DIRECTORY/JetBrains/keymaps"

# Function to detect platform and set JetBrains directory
detect_platform() {
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        # Windows
        if [[ -n "$APPDATA" ]]; then
            JETBRAINS_DIR="$APPDATA/JetBrains"
        else
            log_error "Error: APPDATA environment variable not found"
            return 1
        fi
        PLATFORM="Windows"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        JETBRAINS_DIR="$HOME/Library/Application Support/JetBrains"
        PLATFORM="macOS"
    else
        log_error "Error: Unsupported platform. This script supports Windows and macOS only."
        return 1
    fi
}

# Function to discover available IDE versions
discover_ide_versions() {
    if [[ ! -d "$JETBRAINS_DIR" ]]; then
        log_error "Error: JetBrains directory not found at: $JETBRAINS_DIR"
        return 1
    fi

    declare -a available_versions=()

    # Scan for IDE directories with version numbers
    for ide in "${IDES[@]}"; do
        for dir in "$JETBRAINS_DIR"/$ide*; do
            if [[ -d "$dir" ]]; then
                dirname=$(basename "$dir")
                # Check if directory name has version number (contains digits after IDE name)
                if [[ "$dirname" =~ ^${ide}[0-9] ]]; then
                    # Check if keymaps directory exists in this IDE version
                    if [[ -d "$dir/keymaps" ]]; then
                        available_versions+=("$dirname")
                    fi
                fi
            fi
        done
    done

    if [[ ${#available_versions[@]} -eq 0 ]]; then
        log_error "No compatible JetBrains IDEs found in: $JETBRAINS_DIR"
        log_info "Looking for directories matching pattern: {IDE}{version} with existing keymaps folder"
        echo "Supported IDEs: ${IDES[*]}"
        return 1
    fi

    # Print each version on a separate line (compatible with both bash and zsh)
    for version in "${available_versions[@]}"; do
        echo "$version"
    done
}

# Function to display selection menu
show_selection_menu() {
    local versions=("$@")
    echo "Available JetBrains IDE versions on $PLATFORM:"
    echo

    local count=1
    for version in "${versions[@]}"; do
        echo "$count. $version"
        ((count++))
    done
    echo
}

# Function to get user selection
get_user_selection() {
    local versions=("$@")
    local selection

    while true; do
        printf "Please select an IDE version (1-${#versions[@]}): " >&2
        read selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#versions[@]} ]]; then
            # Use a counter to get the selected version (compatible with both bash and zsh)
            local count=1
            for version in "${versions[@]}"; do
                if [[ $count -eq $selection ]]; then
                    echo "$version"
                    return 0
                fi
                ((count++))
            done
        else
            echo "Invalid selection. Please enter a number between 1 and ${#versions[@]}." >&2
        fi
    done
}

# Function to copy keymaps
copy_keymaps() {
    local selected_ide="$1"
    local target_dir="$JETBRAINS_DIR/$selected_ide/keymaps"

    if [[ ! -d "$KEYMAP_SOURCE" ]]; then
        log_error "Error: Source keymaps directory not found at: $KEYMAP_SOURCE"
        return 1
    fi

    if [[ ! -d "$target_dir" ]]; then
        log_error "Error: Target directory not found: $target_dir"
        return 1
    fi

    log_info "Copying keymaps from: $KEYMAP_SOURCE"
    log_info "To: $target_dir"
    echo

    # Create backup if keymaps already exist
    local backup_created=false
    for keymap in "$KEYMAP_SOURCE"/*.xml; do
        if [[ -f "$keymap" ]]; then
            local filename=$(basename "$keymap")
            if [[ -f "$target_dir/$filename" ]] && [[ "$backup_created" == false ]]; then
                local backup_dir="$target_dir/backup_$(date +%Y%m%d_%H%M%S)"
                log_info "Existing keymaps found. Creating backup at: $backup_dir"
                mkdir -p "$backup_dir"
                cp "$target_dir"/*.xml "$backup_dir" 2>/dev/null || true

                # Clear the keymap directory after backup
                log_info "Clearing existing keymaps from target directory..."
                rm -f "$target_dir"/*.xml
                backup_created=true
            fi
        fi
    done

    # Copy keymaps
    local copied_count=0
    for keymap in "$KEYMAP_SOURCE"/*.xml; do
        if [[ -f "$keymap" ]]; then
            local filename=$(basename "$keymap")
            cp "$keymap" "$target_dir/"
            if [[ $? -eq 0 ]]; then
                log_success "✓ Copied: $filename"
                ((copied_count++))
            else
                log_error "✗ Failed to copy: $filename"
            fi
        fi
    done

    echo
    if [[ $copied_count -gt 0 ]]; then
        log_success "Successfully copied $copied_count keymap(s) to $selected_ide"
        echo
        log_info "The keymaps should now be available in your IDE under:"
        log_info "Settings → Keymap → [Select your custom keymap]"
        log_info "You may need to restart your IDE for the changes to take effect."
    else
        log_error "No keymaps were copied."
    fi
}

# Main execution
jb_configure_main() {
    log_info "JetBrains Keymap Copy Utility"
    log_info "============================="
    echo

    # Detect platform and set JetBrains directory
    detect_platform
    log_info "Detected platform: $PLATFORM"
    log_info "JetBrains directory: $JETBRAINS_DIR"
    log_info "Keymap source: $KEYMAP_SOURCE"
    echo

    # Discover available IDE versions (compatible with both bash and zsh)
    local available_versions=()
    while IFS= read -r line; do
        available_versions+=("$line")
    done < <(discover_ide_versions)

    # Check if discover_ide_versions failed
    if [[ ${#available_versions[@]} -eq 0 ]]; then
        return 1
    fi

    if [[ ${#available_versions[@]} -eq 1 ]]; then
        # Get the first (and only) element in a portable way
        local first_version
        for version in "${available_versions[@]}"; do
            first_version="$version"
            break
        done
        log_info "Found 1 compatible IDE version: $first_version"
        printf "Copy keymaps to $first_version? (y/N): " >&2
        read confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            copy_keymaps "$first_version"
        else
            log_error "Operation cancelled."
        fi
    else
        # Show selection menu
        show_selection_menu "${available_versions[@]}"

        # Get user selection
        selected_ide=$(get_user_selection "${available_versions[@]}")
        echo
        log_info "Selected: $selected_ide"

        # Confirm and copy
        printf "Copy keymaps to $selected_ide? (y/N): " >&2
        read confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo
            copy_keymaps "$selected_ide"
        else
            log_error "Operation cancelled."
        fi
    fi
}

# Run main function
jb_configure_main "$@"