#
# Copyright (c) 2025. Encore Digital Group.
# All Right Reserved.
#

# Load Configurations (Ordering Matters)
source "$DF_CONFIG_DIRECTORY/env.sh"
source "$DF_CONFIG_DIRECTORY/color.sh"
source "$DF_CONFIG_DIRECTORY/alias.sh"
source "$DF_CONFIG_DIRECTORY/func.sh"

# Load Tool Configurations (Sorted Alphabetically)
source "$DF_TOOLS_DIRECTORY/aws.sh"
source "$DF_TOOLS_DIRECTORY/docker.sh"

# Conditionally Load Entrypoint to Private DotFiles
DF_PRIVATE_DIRECTORY="$HOME/Documents/GitHub/dotfiles-private"
[ -f "$DF_PRIVATE_DIRECTORY/entrypoint.sh" ] && source "$DF_PRIVATE_DIRECTORY/entrypoint.sh"