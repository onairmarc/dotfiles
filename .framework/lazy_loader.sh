#!/bin/bash

#
# Copyright (c) 2025. Encore Digital Group.
# All Right Reserved.
#

# Lazy loading framework for tools and heavy scripts

# Function to create lazy-loaded commands from one script
__df_lazy_load() {
    local script_path="$1"
    local script_id="${2:-$(basename "$script_path" .sh)}"
    shift 2
    local commands=("$@")

    for command_name in "${commands[@]}"; do
        eval "${command_name}() {
            # Load the actual script
            __df_source_once '$script_path' '$script_id'

            # Remove all lazy loader functions for this script
            for cmd in ${commands[@]}; do
                unset -f \$cmd
            done

            # Execute the actual command if it exists
            if declare -f $command_name >/dev/null 2>&1; then
                $command_name \"\$@\"
            elif command -v $command_name >/dev/null 2>&1; then
                $command_name \"\$@\"
            else
                echo \"Error: Command '$command_name' not found after loading $script_path\" >&2
                return 1
            fi
        }"
    done
}