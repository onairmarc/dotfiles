# DF_ROOT_DIRECTORY: env-var-with-fallback (matches install.sh / install.ps1)
: "${DF_ROOT_DIRECTORY:=$HOME/Documents/GitHub/dotfiles}"
export DF_ROOT_DIRECTORY
export DF_DATA_DIR="${DF_DATA_DIR:-$HOME/.df_data}"

# OMZ prelude — must run *before* antidote loads ohmyzsh/ohmyzsh because OMZ reads these
# variables when oh-my-zsh.sh is sourced.
export ZSH="$HOME/.oh-my-zsh"
export ZSH_THEME="robbyrussell"
export ZSH_CUSTOM="$DF_ROOT_DIRECTORY/ohmyzsh/custom"
COMPLETION_WAITING_DOTS="true"
zstyle ':omz:update' mode auto

# antidote bootstrap (installed by provisioner as `brew install antidote`)
source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
antidote load "$DF_ROOT_DIRECTORY/zsh_plugins.cfg"

# OMZ postlude — runs *after* antidote has loaded OMZ + autosuggestions + syntax-highlighting,
# so the keybinding can attach to the autosuggest widget.
bindkey '^I' autosuggest-accept
ZSH_COLORIZE_TOOL=chroma
ZSH_COLORIZE_STYLE="colorful"

# Conditionally load private dotfiles
[ -f "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh" ] && \
  source "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh"

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
