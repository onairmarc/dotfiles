# Automatically reload tmux configuration
if command -v tmux > /dev/null; then
    # Only reload tmux config if tmux is running
    if [ -n "$TMUX" ]; then
        tmux source-file "$DF_TOOLS_DIRECTORY/tmux.conf"
    fi
fi
