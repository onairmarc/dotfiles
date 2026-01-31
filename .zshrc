export DF_ROOT_DIRECTORY="$HOME/Documents/GitHub/dotfiles"

source "$DF_ROOT_DIRECTORY/entrypoint.sh"

# Added by CodeRabbit CLI installer
export PATH="/Users/marcbeinder/.local/bin:$PATH"

# Herd injected PHP 8.3 configuration.
export HERD_PHP_83_INI_SCAN_DIR="/Users/marcbeinder/Library/Application Support/Herd/config/php/83/"

# Herd injected PHP 8.4 configuration.
export HERD_PHP_84_INI_SCAN_DIR="/Users/marcbeinder/Library/Application Support/Herd/config/php/84/"

# Herd injected PHP 8.5 configuration.
export HERD_PHP_85_INI_SCAN_DIR="/Users/marcbeinder/Library/Application Support/Herd/config/php/85/"

# opencode
export PATH=/Users/marcbeinder/.opencode/bin:$PATH

# bun completions
[ -s "/Users/marcbeinder/.oh-my-zsh/completions/_bun" ] && source "/Users/marcbeinder/.oh-my-zsh/completions/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
