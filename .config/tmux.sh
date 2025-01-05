# Automatically reload tmux configuration
if command -v tmux > /dev/null; then
    # Only reload tmux config if tmux is running
    if [ -n "$TMUX" ]; then
        tmux source-file ~/Documents/GitHub/dotfiles/.tools/tmux.conf
    fi
fi
