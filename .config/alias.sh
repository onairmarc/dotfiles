#background=dark

# Add RVM to PATH for scripting. Make sure this is the last PATH variable chang$
alias analize='vendor/bin/phpstan analyse'
alias art='php artisan'
alias build='npm run build'
alias battery='pmset -g batt'
alias ccc='npm cache clean --force && composer clear-cache'
alias cf='composer format'
alias ci='composer install --ignore-platform-reqs'
alias cu='composer update --ignore-platform-reqs'
alias cls='clear'
alias db='build && duster fix'
alias dc='docker-compose'
alias dep='vendor/bin/dep'
alias docker-composer='docker-compose'
alias doctum='php doctum.phar'
alias dotfiles='gh && cd dotfiles'
alias dust='duster'
alias duster='vendor/bin/duster'
alias epp='art'
#alias gauntlet='rector && duster fix && analize'
alias gh='github'
alias gs='git status'
alias github='cd ~/Documents/GitHub'
alias gitnah='git reset --hard'
alias gpo='git pull origin'
alias install='npm install && composer install --ignore-platform-reqs'
alias list='ls -la'
alias linecount='git ls-files | xargs cat | wc -l'
alias linecountdetail='git ls-files | xargs wc -l'
alias migrate='art migrate'
alias mono='vendor/bin/monorepo-builder'
alias mpc='art'
alias pest='vendor/bin/pest'
alias phpunit='vendor/bin/phpunit'
alias rector='vendor/bin/rector'
alias sail='vendor/bin/sail'
alias scribe='php artisan scribe:generate --scribe-dir=.config/scribe'
alias serve='sl'
alias silence='git update-index --skip-worktree'
alias sl='art serve'
alias spin='[ -f node_modules/.bin/spin ] && bash node_modules/.bin/spin || bash vendor/bin/spin'
alias tf='terraform'
alias tfapply='tf_apply'
alias tfmode='tf_mode'
alias tfplan='tf_plan'
alias unsilence='git update-index --no-skip-worktree'
alias x='exit'
alias zpe='zp'
#alias zshm='export ZSH="$HOME/.oh-my-zsh"'
#alias zshw='export ZSH="\\\wsl.localhost\\Ubuntu\\home\\marcbeinder\\.oh-my-zsh"'