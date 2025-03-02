# Check if .nanorc exists, and if not, create it with default settings
if [[ ! -f ~/.nanorc ]]; then
    cp "$DF_TOOLS_DIRECTORY/.nanorc" "$HOME/.nanorc"
    echo "Created .nanorc file"
fi
