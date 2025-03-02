#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.
set -u  # Treat unset variables as an error.

echo "Starting Mac setup..."

# Variables
DOTFILES_REPO="https://github.com/onairmarc/dotfiles.git"
DOTFILES_DIRECTORY="~/Documents/GitHub/dotfiles"
ENTRYPOINT_SCRIPT="$DOTFILES_DIRECTORY/entrypoint.sh"

# Ensure Homebrew is installed
if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed."
fi

echo "Updating Homebrew..."
brew update

# Ensure Git is installed
if ! command -v git &>/dev/null; then
    echo "Git not found. Installing Git..."
    brew install git
else
    echo "Git is already installed."
fi

# Clone dotfiles repo
echo "Cloning dotfiles repository..."
if [ ! -d "$DOTFILES_DIRECTORY" ]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIRECTORY" || {
        echo "Failed to clone $DOTFILES_REPO. Directory may not be empty. Skipping this step."
    }
else
    echo "Dotfiles directory already exists."
fi

# Ensure Zsh is installed
if ! command -v zsh &>/dev/null; then
    echo "Zsh not found. Installing Zsh..."
    brew install zsh
else
    echo "Zsh is already installed."
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh not found. Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
        echo "Failed to install Oh My Zsh."
    }
else
    echo "Oh My Zsh is already installed."
fi

# Source the entrypoint script with Zsh
if [ -f "$ENTRYPOINT_SCRIPT" ]; then
    echo "Sourcing entrypoint script using Zsh..."
    zsh -c "source $ENTRYPOINT_SCRIPT" || {
        echo "Failed to source $ENTRYPOINT_SCRIPT. Please check its contents."
    }
else
    echo "Entrypoint script not found. Please check the path: $ENTRYPOINT_SCRIPT"
fi

# Function to check and install a tool
install_tool() {
    local tool_name=$1
    local brew_command=$2
    local app_path=$3

    if [ -d "$app_path" ]; then
        echo "$tool_name is already installed at $app_path. Skipping installation."
    elif ! brew list --cask "$tool_name" &>/dev/null && ! brew list "$tool_name" &>/dev/null; then
        echo "Installing $tool_name..."
        eval "$brew_command"
    else
        echo "$tool_name is already installed."
    fi
}

# Install software
install_tool "raycast" "brew install --cask raycast" "/Applications/Raycast.app"
install_tool "jetbrains-toolbox" "brew install --cask jetbrains-toolbox" "/Applications/JetBrains Toolbox.app"
install_tool "chrome" "brew install --cask google-chrome" "/Applications/Google Chrome.app"
install_tool "herd" "brew install --cask herd" "/Applications/Herd.app"
install_tool "shottr" "brew install --cask shottr" "/Applications/Shottr.app"
install_tool "1password" "brew install --cask 1password" "/Applications/1Password.app"
install_tool "1password-cli" "brew install 1password-cli" ""  # CLI tool, no specific app path
install_tool "tmux" "brew install tmux" ""  # CLI tool, no specific app path
install_tool "htop" "brew install htop" ""  # CLI tool, no specific app path
install_tool "nano" "brew install nano" ""  # CLI tool, no specific app path
install_tool "zsh-autosuggestions" "brew install zsh-autosuggestions" ""  # CLI tool, no specific app path
install_tool "zsh-syntax-highlighting" "brew install zsh-syntax-highlighting" ""  # CLI tool, no specific app path
install_tool "stripe-cli" "brew install stripe/stripe-cli/stripe" "" #CLI tool, no specific app path
install_tool "mac-cleanup" "brew tap fwartner/tap && brew install fwartner/tap/mac-cleanup" "" #CLI tool, no specific app path

echo "Setup completed! You may need to restart your terminal for some changes to take effect."
