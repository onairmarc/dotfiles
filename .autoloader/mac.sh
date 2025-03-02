#
# Copyright (c) 2025. Encore Digital Group.
# All Right Reserved.
#

# OMZ must be loaded first
source "$DF_CONFIG_DIRECTORY/omz.sh"

# Load Configurations (Ordering Matters)
source "$DF_CONFIG_DIRECTORY/env.sh"
source "$DF_CONFIG_DIRECTORY/color.sh"
source "$DF_CONFIG_DIRECTORY/alias.sh"
source "$DF_CONFIG_DIRECTORY/func.sh"

# Load Tool Configurations (Sorted Alphabetically)
source "$DF_TOOLS_DIRECTORY/aws.sh"
source "$DF_TOOLS_DIRECTORY/docker.sh"
source "$DF_CONFIG_DIRECTORY/mac.sh"
source "$DF_TOOLS_DIRECTORY/mac_cleanup_checker.sh"
source "$DF_TOOLS_DIRECTORY/nano.sh"
source "$DF_TOOLS_DIRECTORY/stripe.sh"
source "$DF_CONFIG_DIRECTORY/tmux.sh"

# Conditionally Load Entrypoint to Private DotFiles
DF_PRIVATE_DIRECTORY="$HOME/Documents/GitHub/dotfiles-private"
[ -f "$DF_PRIVATE_DIRECTORY/entrypoint.sh" ] && source "$DF_PRIVATE_DIRECTORY/entrypoint.sh"