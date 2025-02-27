# Check if .nanorc exists, and if not, create it with default settings
if [[ ! -f ~/.nanorc ]]; then
    cp ~/Documents/GitHub/dotfiles/.tools/.nanorc ~/.nanorc
    echo "Created .nanorc file"
fi
