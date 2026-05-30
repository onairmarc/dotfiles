if [ -n "$ZSH_VERSION" ]; then
  return 0   # .zshrc handles everything via antidote
fi
: "${DF_ROOT_DIRECTORY:=$HOME/Documents/GitHub/dotfiles}"
export DF_ROOT_DIRECTORY
source "$DF_ROOT_DIRECTORY/framework/bash_loader.sh"
