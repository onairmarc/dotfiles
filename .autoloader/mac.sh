#
# Copyright (c) 2025. Encore Digital Group.
# All Right Reserved.
#

# Start timing for debug mode
if [[ -n "$DF_DEBUG_TIMING" ]]; then
    _mac_autoloader_start_time=$(date +%s%3N)
fi

# OMZ must be loaded first
__df_source_once "$DF_CONFIG_DIRECTORY/omz.sh" "omz"

# Load Configurations (Ordering Matters)
__df_source_once "$DF_CONFIG_DIRECTORY/env.sh" "env"
__df_source_once "$DF_CONFIG_DIRECTORY/color.sh" "color"
__df_source_once "$DF_CONFIG_DIRECTORY/alias.sh" "alias"
__df_source_once "$DF_CONFIG_DIRECTORY/func.sh" "func"

# Load Tool Configurations (Sorted Alphabetically)
__df_source_once "$DF_TOOLS_DIRECTORY/aws.sh" "aws"
__df_source_once "$DF_TOOLS_DIRECTORY/docker.sh" "docker"
__df_source_once "$DF_CONFIG_DIRECTORY/mac.sh" "mac"
__df_source_once "$DF_TOOLS_DIRECTORY/mac_cleanup_checker.sh" "mac_cleanup_checker"
__df_source_once "$DF_TOOLS_DIRECTORY/nano.sh" "nano"
__df_source_once "$DF_TOOLS_DIRECTORY/stripe.sh" "stripe"
__df_source_once "$DF_CONFIG_DIRECTORY/tmux.sh" "tmux"

# Conditionally Load Entrypoint to Private DotFiles
DF_PRIVATE_DIRECTORY="$HOME/Documents/GitHub/dotfiles-private"
[ -f "$DF_PRIVATE_DIRECTORY/entrypoint.sh" ] && source "$DF_PRIVATE_DIRECTORY/entrypoint.sh"

# End timing for debug mode
if [[ -n "$DF_DEBUG_TIMING" ]]; then
    _mac_autoloader_end_time=$(date +%s%3N)
    echo "[TIMING] mac autoloader: $((_mac_autoloader_end_time - _mac_autoloader_start_time))ms" >&2
fi