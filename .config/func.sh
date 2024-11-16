
loc() {
  phploc . --exclude=vendor
}

nah() {
    git reset --hard;
}

npmcc() {
    npm cache clean --force;
}

rebuild() {
    rmd && ccc && install && build;
}

rmd() {
    rm -rf node_modules && rm -rf vendor;
}

rollback() {
    art migrate:rollback;
}

sys_env_clean() {
  rm -f .env.testing
  rm -f .env.production
}

sys_env_decrypt() {
    if [ -z "$1" ]; then
      echo -e "${COL_RED}Error: Environment is required.${COL_RESET}"
      return 1
    fi
  
  local environment=$1
  
  rm -f ./.env.$environment
  
  php artisan env:decrypt --env=$environment --key=$ENCORE_DIGITAL_ENV_ENCRYPTION_KEY
}

sys_env_encrypt() {
    if [ -z "$1" ]; then
      echo -e "${COL_RED}Error: Environment is required.${COL_RESET}"
      return 1
    fi
  
  local environment=$1
  
  rm -f ./.env.$environment.encrypted
  php artisan env:encrypt --env=$environment --key=$ENCORE_DIGITAL_ENV_ENCRYPTION_KEY
}

tf_import_repo () {
  local repo_name=$1
  local repo_id=${2:-$1}
  local tf_mode=$(tf_get_mode)
  
  # Decide what to do based on the returned value
  if [ "$tf_mode" = "phpgenesis" ]; then
    # Action A: Do something if mode is phpgenesis
    tf import module.$repo_name.module.repo.github_repository.repo $repo_id
    # Add your code for Action A here
  elif [ "$tf_mode" = "encore" ]; then
    # Action B: Do something if mode is encore
    tf import module.github_repos.module.$repo_name.github_repository.repo $repo_id
    # Add your code for Action B here
  else
    echo -e "${COL_RED}Unknown Terraform Mode: $tf_mode${COL_RESET}"
  fi
}

tf_set_mode() {
  local tf_mode=$1
  echo $tf_mode > ~/.tfmode
}

tf_get_mode() {
  # Check if the file exists and is not empty
  if [ -s "$HOME/.tfmode" ]; then
    # Print the contents of ~/.tfmode
    cat "$HOME/.tfmode"
  else
    # Print error message in bright red text if file doesn't exist or is empty
    echo -e "${COL_RED}Void${COL_RESET}"
  fi
}

tf_mode() {
  if [ "$1" = "set" ]; then
    tf_set_mode $2
  elif [ "$1" = "unset" ]; then
    rm ~/.tfmode
  elif [ -z "$1" ]; then
    tf_get_mode
  fi
}


tf_plan() {
  tf plan -out plan
}

tf_apply() {
  tf apply plan
}

zp() {
  nano ~/Documents/GitHub/dotfiles/.config/config.sh;
}

zpew() {
  zp
}

zpw-refresh() {
  source ~/.bash_profile;
}

zpm-refresh() {
  source ~/.zshrc;
}

zpw() {
    rm ~/.bash_profile && cp ~/Documents/GitHub/dotfiles/.zshrc ~/.bash_profile && zpw-refresh;
}

zpwi() {
    cp ~/Documents/GitHub/dotfiles/.zshrc ~/.bash_profile && zpw-refresh;
}

zpm() {
	rm ~/.zshrc && ln -s ~/Documents/GitHub/dotfiles/.zshrc ~/.zshrc && zpm-refresh;
}

zpi() {
    rm ~/.zshrc && ln -s ~/dotfiles/.zshrc ~/.zshrc && zpm-refresh;
}