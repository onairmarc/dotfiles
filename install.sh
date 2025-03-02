#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.
set -u  # Treat unset variables as an error.
source "./.autoloader/autoloader.sh"
source "$DF_CONFIG_DIRECTORY/color.sh"

echo "Starting Mac setup..."

# Variables
DOTFILES_REPO="https://github.com/onairmarc/dotfiles.git"
DOTFILES_DIRECTORY="~/Documents/GitHub/dotfiles"
ENTRYPOINT_SCRIPT="$DOTFILES_DIRECTORY/entrypoint.sh"

# Ensure Homebrew is installed
if ! command -v brew &>/dev/null; then
    echo -e "${COL_YELLOW}Homebrew not found. Installing Homebrew...${COL_RESET}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo -e "${COL_GREEN}Homebrew is already installed.${COL_RESET}"
fi

echo -e "${COL_CYAN}Updating Homebrew...${COL_RESET}"
brew update

# Ensure Git is installed
if ! command -v git &>/dev/null; then
    echo -e "${COL_YELLOW}Git not found. Installing Git...${COL_RESET}"
    brew install git
else
    echo -e "${COL_GREEN}Git is already installed.${COL_RESET}"
fi

# Clone dotfiles repo
echo -e "${COL_CYAN}Cloning dotfiles repository...${COL_RESET}"
if [ ! -d "$DOTFILES_DIRECTORY" ]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIRECTORY" || {
        echo -e "${COL_RED}Failed to clone $DOTFILES_REPO. Directory may not be empty. Skipping this step.${COL_RESET}"
    }
else
    echo -e "${COL_GREEN}Dotfiles directory already exists.${COL_RESET}"
fi

# Ensure Zsh is installed
if ! command -v zsh &>/dev/null; then
    echo -e "${COL_YELLOW}Zsh not found. Installing Zsh...${COL_RESET}"
    brew install zsh
else
    echo -e "${COL_GREEN}Zsh is already installed.${COL_RESET}"
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${COL_YELLOW}Oh My Zsh not found. Installing Oh My Zsh...${COL_RESET}"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
        echo -e "${COL_RED}Failed to install Oh My Zsh.${COL_RESET}"
    }
else
    echo -e "${COL_GREEN}Oh My Zsh is already installed.${COL_RESET}"
fi

# Source the entrypoint script with Zsh
if [ -f "$ENTRYPOINT_SCRIPT" ]; then
    echo -e "${COL_CYAN}Sourcing entrypoint script using Zsh...${COL_RESET}"
    zsh -c "source $ENTRYPOINT_SCRIPT" || {
        echo -e "${COL_RED}Failed to source $ENTRYPOINT_SCRIPT. Please check its contents.${COL_RESET}"
    }
else
    echo -e "${COL_RED}Entrypoint script not found. Please check the path: $ENTRYPOINT_SCRIPT${COL_RESET}"
fi

# Store the output of brew list and brew list --cask in an environment variable
BREW_LIST=$(brew list)
BREW_CASK_LIST=$(brew list --cask)

# Function to check and install a tool
install_tool() {
    local tool_name=$1
    local brew_command=$2
    local app_path="${3:-}"
    local already_installed="${COL_GREEN}$tool_name is already installed.${COL_RESET}"

    if [ -d "$app_path" ]; then
        echo -e "$already_installed"
    elif [[ "$BREW_LIST" == *"$tool_name"* ]] || [[ "$BREW_CASK_LIST" == *"$tool_name"* ]]; then
        echo -e "$already_installed"
    else
        echo -e "${COL_YELLOW}Installing $tool_name...${COL_RESET}"
        eval "$brew_command"
    fi
}

# Install software
install_tool "1password" "brew install --cask 1password" "/Applications/1Password.app"
install_tool "1password-cli" "brew install 1password-cli"
install_tool "chroma" "brew install chroma"
install_tool "chrome" "brew install --cask google-chrome" "/Applications/Google Chrome.app"
install_tool "doctl" "brew install doctl"
install_tool "git-extras" "brew install git-extras"
install_tool "git-filter-repo" "brew install git-filter-repo"
install_tool "herd" "brew install --cask herd" "/Applications/Herd.app"
install_tool "htop" "brew install htop"
install_tool "jetbrains-toolbox" "brew install --cask jetbrains-toolbox" "/Applications/JetBrains Toolbox.app"
install_tool "jq" "brew install jq"
install_tool "mac-cleanup" "brew tap fwartner/tap && brew install fwartner/tap/mac-cleanup"
install_tool "nano" "brew install nano"
install_tool "pygments" "brew install pygments"
install_tool "raycast" "brew install --cask raycast" "/Applications/Raycast.app"
install_tool "rsync" "brew install rsync"
install_tool "saml2aws" "brew install saml2aws"
install_tool "shottr" "brew install --cask shottr" "/Applications/Shottr.app"
install_tool "stripe-cli" "brew install stripe-cli"
install_tool "terraform" "brew install terraform"
install_tool "tmux" "brew install tmux"
install_tool "zsh-autosuggestions" "brew install zsh-autosuggestions"
install_tool "zsh-syntax-highlighting" "brew install zsh-syntax-highlighting"

# Unset the environment variables
unset BREW_LIST
unset BREW_CASK_LIST

echo -e "${COL_CYAN}"
stripe completion
echo -e "${COL_RESET}"
if [ ! -f ~/.stripe ]; then
  rm -rf ~/.stripe  
  mkdir -p ~/.stripe
fi
mv stripe-completion.zsh ~/.stripe

echo
echo -e "${COL_GREEN}Setup completed! You may need to restart your terminal for some changes to take effect.${COL_RESET}"