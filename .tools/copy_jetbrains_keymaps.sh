#!/bin/bash

# JetBrains Keymap Copy Script
# Copies keymaps from the dotfiles repository to platform-specific JetBrains directories

# Define supported IDEs
IDES=("GoLand" "PhpStorm" "WebStorm" "IntelliJIdea" "Rider" "PyCharm" "CLion" "RubyMine" "DataGrip" "AndroidStudio")

# Set the dotfiles repository keymap source (fixed path)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYMAP_SOURCE="$DOTFILES_ROOT/JetBrains/keymaps"

# Function to detect platform and set JetBrains directory
detect_platform() {
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        # Windows
        if [[ -n "$APPDATA" ]]; then
            JETBRAINS_DIR="$APPDATA/JetBrains"
        else
            echo "Error: APPDATA environment variable not found"
            exit 1
        fi
        PLATFORM="Windows"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        JETBRAINS_DIR="$HOME/Library/Application Support/JetBrains"
        PLATFORM="macOS"
    else
        echo "Error: Unsupported platform. This script supports Windows and macOS only."
        exit 1
    fi
}

# Function to discover available IDE versions
discover_ide_versions() {
    if [[ ! -d "$JETBRAINS_DIR" ]]; then
        echo "Error: JetBrains directory not found at: $JETBRAINS_DIR"
        exit 1
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
        echo "No compatible JetBrains IDEs found in: $JETBRAINS_DIR"
        echo "Looking for directories matching pattern: {IDE}{version} with existing keymaps folder"
        echo "Supported IDEs: ${IDES[*]}"
        exit 1
    fi

    printf '%s\n' "${available_versions[@]}"
}

# Function to display selection menu
show_selection_menu() {
    local versions=("$@")
    echo "Available JetBrains IDE versions on $PLATFORM:"
    echo

    for i in "${!versions[@]}"; do
        echo "$((i+1)). ${versions[i]}"
    done
    echo
}

# Function to get user selection
get_user_selection() {
    local versions=("$@")
    local selection

    while true; do
        read -p "Please select an IDE version (1-${#versions[@]}): " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#versions[@]} ]]; then
            echo "${versions[$((selection-1))]}"
            return 0
        else
            echo "Invalid selection. Please enter a number between 1 and ${#versions[@]}."
        fi
    done
}

# Function to copy keymaps
copy_keymaps() {
    local selected_ide="$1"
    local target_dir="$JETBRAINS_DIR/$selected_ide/keymaps"

    if [[ ! -d "$KEYMAP_SOURCE" ]]; then
        echo "Error: Source keymaps directory not found at: $KEYMAP_SOURCE"
        exit 1
    fi

    if [[ ! -d "$target_dir" ]]; then
        echo "Error: Target directory not found: $target_dir"
        exit 1
    fi

    echo "Copying keymaps from: $KEYMAP_SOURCE"
    echo "To: $target_dir"
    echo

    # Create backup if keymaps already exist
    local backup_created=false
    for keymap in "$KEYMAP_SOURCE"/*.xml; do
        if [[ -f "$keymap" ]]; then
            local filename=$(basename "$keymap")
            if [[ -f "$target_dir/$filename" ]] && [[ "$backup_created" == false ]]; then
                local backup_dir="$target_dir/backup_$(date +%Y%m%d_%H%M%S)"
                echo "Existing keymaps found. Creating backup at: $backup_dir"
                mkdir -p "$backup_dir"
                cp "$target_dir"/*.xml "$backup_dir" 2>/dev/null || true

                # Clear the keymap directory after backup
                echo "Clearing existing keymaps from target directory..."
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
                echo "✓ Copied: $filename"
                ((copied_count++))
            else
                echo "✗ Failed to copy: $filename"
            fi
        fi
    done

    echo
    if [[ $copied_count -gt 0 ]]; then
        echo "Successfully copied $copied_count keymap(s) to $selected_ide"
        echo
        echo "The keymaps should now be available in your IDE under:"
        echo "Settings → Keymap → [Select your custom keymap]"
    else
        echo "No keymaps were copied."
    fi
}

# Main execution
main() {
    echo "JetBrains Keymap Copy Utility"
    echo "============================="
    echo

    # Detect platform and set JetBrains directory
    detect_platform
    echo "Detected platform: $PLATFORM"
    echo "JetBrains directory: $JETBRAINS_DIR"
    echo "Keymap source: $KEYMAP_SOURCE"
    echo

    # Discover available IDE versions
    mapfile -t available_versions < <(discover_ide_versions)

    if [[ ${#available_versions[@]} -eq 1 ]]; then
        echo "Found 1 compatible IDE version: ${available_versions[0]}"
        read -p "Copy keymaps to ${available_versions[0]}? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            copy_keymaps "${available_versions[0]}"
        else
            echo "Operation cancelled."
        fi
    else
        # Show selection menu
        show_selection_menu "${available_versions[@]}"

        # Get user selection
        selected_ide=$(get_user_selection "${available_versions[@]}")
        echo
        echo "Selected: $selected_ide"

        # Confirm and copy
        read -p "Copy keymaps to $selected_ide? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo
            copy_keymaps "$selected_ide"
        else
            echo "Operation cancelled."
        fi
    fi
}

# Run main function
main "$@"