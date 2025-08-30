#
# Copyright (c) 2025. Encore Digital Group.
# All Right Reserved.
#

# Root DotFiles Directory Env
export DF_ROOT_DIRECTORY="$HOME/Documents/GitHub/dotfiles"

# Module Specific Directory Envs
export DF_AUTOLOADER_DIRECTORY="$DF_ROOT_DIRECTORY/.autoloader"
export DF_CONFIG_DIRECTORY="$DF_ROOT_DIRECTORY/.config"
export DF_TOOLS_DIRECTORY="$DF_ROOT_DIRECTORY/.tools"

# Load migration functions
if [ -f "$DF_ROOT_DIRECTORY/.framework/migrations/migrate.sh" ]; then
    source "$DF_ROOT_DIRECTORY/.framework/migrations/migrate.sh"
fi

# Load migration helpers
if [ -f "$DF_ROOT_DIRECTORY/.framework/migrations/migration_helpers.sh" ]; then
    source "$DF_ROOT_DIRECTORY/.framework/migrations/migration_helpers.sh"
fi
