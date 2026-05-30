#!/usr/bin/env bash
set -eu

DOTFILES_REPO="https://github.com/onairmarc/dotfiles.git"
: "${DF_ROOT_DIRECTORY:=$HOME/Documents/GitHub/dotfiles}"
export DF_ROOT_DIRECTORY

# Ensure Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
    echo "[*] Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "[+] Homebrew is already installed."
fi

brew update

# Ensure Lua and Git are installed
for pkg in lua git; do
    if command -v "$pkg" >/dev/null 2>&1; then
        echo "[+] $pkg is already installed."
    else
        echo "[*] Installing $pkg..."
        brew install "$pkg"
    fi
done

# Clone dotfiles repo if not present
if [ ! -d "$DF_ROOT_DIRECTORY" ]; then
    echo "[*] Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$DF_ROOT_DIRECTORY"
else
    echo "[+] Dotfiles directory already exists at $DF_ROOT_DIRECTORY."
fi

# Symlink ~/.zshrc and ~/.bashrc to repo .zshrc
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    target="$DF_ROOT_DIRECTORY/.zshrc"
    if [ -L "$rc" ]; then
        current="$(readlink "$rc")"
        if [ "$current" = "$target" ]; then
            echo "[+] $rc already symlinked to repo .zshrc."
            continue
        fi
        rm "$rc"
    elif [ -e "$rc" ]; then
        backup="$rc.bak.$(date +%Y%m%d%H%M%S)"
        echo "[*] Backing up existing $rc to $backup"
        mv "$rc" "$backup"
    fi
    ln -s "$target" "$rc"
    echo "[+] Symlinked $rc -> $target"
done

cd "$DF_ROOT_DIRECTORY"
exec lua provision/main.lua mac "$@"
