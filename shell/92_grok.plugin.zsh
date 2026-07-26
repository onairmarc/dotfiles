# Grok CLI (xAI) — PATH and completions.
# Binary is installed by provision scripts.grok (https://x.ai/cli/install.sh).
# The provisioner clears SHELL during install so the upstream installer does not
# rewrite ~/.zshrc; this file is the managed equivalent of its shell block.

case ":$PATH:" in
  *":$HOME/.grok/bin:"*) ;;
  *) PATH="$HOME/.grok/bin:$PATH" ;;
esac
export PATH

if [ -n "${ZSH_VERSION:-}" ]; then
  fpath=("$HOME/.grok/completions/zsh" $fpath)
  autoload -Uz compinit && compinit -C
elif [ -r "$HOME/.grok/completions/bash/grok.bash" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.grok/completions/bash/grok.bash"
fi
