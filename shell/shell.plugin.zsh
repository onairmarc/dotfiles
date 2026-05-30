# antidote loads this single file for the local plugin. It sources every numbered
# .plugin.zsh sibling in lexical order. The same loop is used by framework/bash_loader.sh
# so zsh and bash get identical load order.
_dir=${0:A:h}
for f in "$_dir"/[0-9]*_*.plugin.zsh; do
  source "$f"
done
unset _dir f
