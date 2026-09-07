#!/usr/bin/env bash
set -eu

DOTFILES_REPO="https://github.com/onairmarc/dotfiles.git"
: "${DF_ROOT_DIRECTORY:=$HOME/Documents/GitHub/dotfiles}"
export DF_ROOT_DIRECTORY

# Homebrew is only used on Apple Silicon Macs. hw.optional.arm64 detects the
# physical hardware correctly when this script runs under Rosetta.
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = "1" ]; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "[*] Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "[+] Homebrew is already installed."
    fi

    brew update
else
    echo "[*] Skipping Homebrew on Intel Mac."
fi

# Ensure Git is installed
if command -v git >/dev/null 2>&1; then
    echo "[+] git is already installed."
else
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = "1" ]; then
        echo "[*] Installing git..."
        brew install git
    else
        echo "[-] git is required on Intel Macs. Install it, then run this script again."
        exit 1
    fi
fi

# Ensure Bun is installed — it is the provisioner runtime (provision/main.ts).
if command -v bun >/dev/null 2>&1; then
    echo "[+] bun is already installed."
else
    echo "[*] Installing bun..."
    curl -fsSL https://bun.sh/install | bash
    # Make bun resolvable in this session (installer adds it to ~/.bun/bin).
    export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi

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
exec bun provision/main.ts mac "$@"
