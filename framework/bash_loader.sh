#!/usr/bin/env bash
# Minimal source-once guard + ordered sourcing for non-zsh shells.
# Mirrors the loop in shell/shell.plugin.zsh so bash and zsh source the same files
# in the same order.

__df_loaded=":"
__df_source_once() {
  case "$__df_loaded" in *":$1:"*) return 0;; esac
  [ -f "$1" ] || return 1
  # shellcheck disable=SC1090
  source "$1"
  __df_loaded="$__df_loaded$1:"
}

for f in "$DF_ROOT_DIRECTORY"/shell/[0-9]*_*.plugin.zsh; do
  __df_source_once "$f"
done

[ -f "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh" ] && \
  source "$HOME/Documents/GitHub/dotfiles-private/entrypoint.sh"
