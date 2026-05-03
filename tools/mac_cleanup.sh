#!/usr/bin/env bash

set -E
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
	trap - SIGINT SIGTERM ERR EXIT
}

# Default arguments
update=false

usage() {
	cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-u]

A Mac Cleaning up Utility by fwartner
https://github.com/mac-cleanup/mac-cleanup-sh

Available options:

-h, --help              Print this help and exit
-d, --dry-run           Print approx space to be cleaned
-v, --verbose           Print script debug info
-u, --update            Run brew update
-s, --thin-snapshots    Aggressively thin APFS local snapshots
-r, --rebuild-index     Rebuild Spotlight index and storage UI caches (CPU heavy, hours)
-R, --regen-report      Run thin-snapshots + rebuild-index together
--regen-only            Skip cleanup; only run report-regen tasks selected by -s/-r/-R
EOF
	exit
}

# shellcheck disable=SC2034  # Unused variables left for readability
setup_colors() {
	if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
		NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
	else
		NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
	fi
}

msg() {
  if [ -z "$dry_run" ]; then
	  echo >&2 -e "${1-}"
	fi
}

die() {
	local msg=$1
	local code=${2-1} # default exit status 1
	msg "$msg"
	exit "$code"
}

parse_params() {
	# default values of variables set from params
	update=false
	thin_snapshots=false
	rebuild_index=false
	regen_only=false

	while :; do
		case "${1-}" in
		-h | --help) usage ;;
		-v | --verbose) set -x ;;
		-d | --dry-run) dry_run=true ;;
		--no-color) NO_COLOR=1 ;;
		-u | --update) update=true ;; # update flag
		-s | --thin-snapshots) thin_snapshots=true ;;
		-r | --rebuild-index) rebuild_index=true ;;
		-R | --regen-report) thin_snapshots=true; rebuild_index=true ;;
		--regen-only) regen_only=true ;;
		-n) true ;;                   # This is a legacy option, now default behaviour
		-?*) die "Unknown option: $1" ;;
		*) break ;;
		esac
		shift
	done

	return 0
}

thin_local_snapshots() {
	if ! type "tmutil" &>/dev/null; then
		msg "${YELLOW}tmutil not available, skipping snapshot thin${NOFORMAT}"
		return 0
	fi
	msg 'Aggressively thinning APFS local snapshots...'
	sudo tmutil thinlocalsnapshots / 999999999999 4 &>/dev/null
	for snap in $(tmutil listlocalsnapshotdates / 2>/dev/null | grep -E '^[0-9]'); do
		sudo tmutil deletelocalsnapshots "$snap" &>/dev/null
	done
}

rebuild_storage_index() {
	msg "${YELLOW}Rebuilding Spotlight index — this will hammer CPU/disk for 1-6 hours.${NOFORMAT}"
	msg 'Disabling Spotlight indexing on /...'
	sudo mdutil -i off / &>/dev/null
	msg 'Erasing Spotlight database...'
	sudo mdutil -E / &>/dev/null
	sudo rm -rf /.Spotlight-V100 &>/dev/null
	msg 'Clearing systemstats cache (drives Storage UI categorization)...'
	sudo rm -rf /private/var/db/systemstats/* &>/dev/null
	sudo rm -rf /System/Volumes/Data/.Spotlight-V100/*
	rm -rf ~/Library/Caches/com.apple.preferencepanes.usercache &>/dev/null
	msg 'Re-enabling Spotlight indexing...'
	sudo mdutil -i on / &>/dev/null
	msg 'Restarting cfprefsd and Finder...'
	killall cfprefsd &>/dev/null
	killall Finder &>/dev/null
	msg "${GREEN}Reindex started in background. Storage panel will update incrementally.${NOFORMAT}"
}

parse_params "$@"
setup_colors

# --regen-only short circuit: skip cleanup, run only selected report-regen tasks
if [ "$regen_only" = true ]; then
	if [ "$thin_snapshots" = false ] && [ "$rebuild_index" = false ]; then
		die "--regen-only requires at least one of -s/--thin-snapshots, -r/--rebuild-index, or -R/--regen-report"
	fi
	sudo -v
	[ "$thin_snapshots" = true ] && thin_local_snapshots
	[ "$rebuild_index" = true ] && rebuild_storage_index
	msg "${GREEN}Done.${NOFORMAT}"
	exit 0
fi

deleteCaches() {
	local cacheName=$1
	shift
	local paths=("$@")
	echo "Initiating cleanup ${cacheName} cache..."
	for folderPath in "${paths[@]}"; do
		if [[ -d ${folderPath} ]]; then
			dirSize=$(du -hs "${folderPath}" | awk '{print $1}')
			echo "Deleting ${folderPath} to free up ${dirSize}..."
			rm -rfv "${folderPath}"
		fi
	done
}

bytesToHuman() {
	b=${1:-0}
	d=''
	s=1
	S=(Bytes {K,M,G,T,E,P,Y,Z}iB)
	while ((b > 1024)); do
		d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
		b=$((b / 1024))
		((s++))
	done
	if [ -z "$dry_results" ]; then
    msg "$b$d ${S[$s]} of space was cleaned up"
  else
    msg "Approx $b$d ${S[$s]} of space will be cleaned up"
  fi
}

count_dry() {
  for path in "${path_list[@]}"; do
    if [ -d "$path" ] || [ -f "$path" ]; then
      temp_dry_results=$(sudo du -ck "$path" | tail -1 | awk '{ print $1 }')
      dry_results="$((dry_results+temp_dry_results))"
    fi
  done
}

remove_paths() {
  if [ -z "$dry_run" ]; then
    for path in "${path_list[@]}"; do
      rm -rfv "$path" &>/dev/null
    done
    unset path_list
  fi
}

collect_paths() {
  path_list+=("$@")
}

# Ask for the administrator password upfront
sudo -v

HOST=$(whoami)

# Keep-alive sudo until `mac-cleanup.sh` has finished
while true; do
	sudo -n true
	sleep 60
	kill -0 "$$" || exit
done 2>/dev/null &

# Enable extended regex
shopt -s extglob

oldAvailable=$(df / | tail -1 | awk '{print $4}')

collect_paths /Volumes/*/.Trashes/*
collect_paths ~/.Trash/*
msg 'Emptying the Trash 🗑 on all mounted volumes and the main HDD...'
remove_paths

collect_paths /Library/Caches/*
collect_paths /System/Library/Caches/*
collect_paths ~/Library/Caches/*
collect_paths /private/var/folders/bh/*/*/*/*
msg 'Clearing System Cache Files...'
remove_paths

collect_paths /private/var/log/asl/*.asl
collect_paths /Library/Logs/DiagnosticReports/*
collect_paths /Library/Logs/CreativeCloud/*
collect_paths /Library/Logs/Adobe/*
collect_paths /Library/Logs/adobegc.log
collect_paths ~/Library/Containers/com.apple.mail/Data/Library/Logs/Mail/*
collect_paths ~/Library/Logs/CoreSimulator/*
msg 'Clearing System Log Files...'
remove_paths

if [ -d ~/Library/Logs/JetBrains/ ]; then
  collect_paths ~/Library/Logs/JetBrains/*/
  msg 'Clearing all application log files from JetBrains...'
  remove_paths
fi

if [ -d ~/Library/Application\ Support/Adobe/ ]; then
  collect_paths ~/Library/Application\ Support/Adobe/Common/Media\ Cache\ Files/*
  msg 'Clearing Adobe Cache Files...'
  remove_paths
fi

if [ -d ~/Library/Application\ Support/Google/Chrome/ ]; then
  collect_paths ~/Library/Application\ Support/Google/Chrome/Default/Application\ Cache/*
  msg 'Clearing Google Chrome Cache Files...'
  remove_paths
fi

collect_paths ~/Music/iTunes/iTunes\ Media/Mobile\ Applications/*
msg 'Cleaning up iOS Applications...'
remove_paths

collect_paths ~/Library/Application\ Support/MobileSync/Backup/*
msg 'Removing iOS Device Backups...'
remove_paths

collect_paths ~/Library/Developer/Xcode/DerivedData/*
collect_paths ~/Library/Developer/Xcode/Archives/*
collect_paths ~/Library/Developer/Xcode/iOS Device Logs/*
msg 'Cleaning up XCode Derived Data and Archives...'
remove_paths

if type "xcrun" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up iOS Simulators...'
    osascript -e 'tell application "com.apple.CoreSimulator.CoreSimulatorService" to quit' &>/dev/null
    osascript -e 'tell application "iOS Simulator" to quit' &>/dev/null
    osascript -e 'tell application "Simulator" to quit' &>/dev/null
    xcrun simctl shutdown all &>/dev/null
    xcrun simctl erase all &>/dev/null
  else
    collect_paths ~/Library/Developer/CoreSimulator/Devices/*/data/!(Library|var|tmp|Media)
    collect_paths /Users/wah/Library/Developer/CoreSimulator/Devices/*/data/Library/!(PreferencesCaches|Caches|AddressBook)
    collect_paths ~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches/*
    collect_paths ~/Library/Developer/CoreSimulator/Devices/*/data/Library/AddressBook/AddressBook*
  fi
fi

# support deleting Dropbox Cache if they exist
if [ -d "/Users/${HOST}/Dropbox" ]; then
  collect_paths ~/Dropbox/.dropbox.cache/*
  msg 'Clearing Dropbox 📦 Cache Files...'
  remove_paths
fi

if [ -d ~/Library/Application\ Support/Google/DriveFS/ ]; then
  collect_paths ~/Library/Application\ Support/Google/DriveFS/[0-9a-zA-Z]*/content_cache
  msg 'Clearing Google Drive File Stream Cache Files...'
  killall "Google Drive File Stream"
  remove_paths
fi

if type "composer" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up composer...'
    composer clearcache --no-interaction &>/dev/null
  else
    collect_paths ~/Library/Caches/composer
  fi
fi

# Deletes Steam caches, logs, and temp files
# -Astro
if [ -d ~/Library/Application\ Support/Steam/ ]; then
  collect_paths ~/Library/Application\ Support/Steam/appcache
  collect_paths ~/Library/Application\ Support/Steam/depotcache
  collect_paths ~/Library/Application\ Support/Steam/logs
  collect_paths ~/Library/Application\ Support/Steam/steamapps/shadercache
  collect_paths ~/Library/Application\ Support/Steam/steamapps/temp
  collect_paths ~/Library/Application\ Support/Steam/steamapps/download
  msg 'Clearing Steam Cache, Log, and Temp Files...'
  remove_paths
fi

# Deletes Minecraft logs
# -Astro
if [ -d ~/Library/Application\ Support/minecraft ]; then
  collect_paths ~/Library/Application\ Support/minecraft/logs
  collect_paths ~/Library/Application\ Support/minecraft/crash-reports
  collect_paths ~/Library/Application\ Support/minecraft/webcache
  collect_paths ~/Library/Application\ Support/minecraft/webcache2
  collect_paths ~/Library/Application\ Support/minecraft/crash-reports
  collect_paths ~/Library/Application\ Support/minecraft/*.log
  collect_paths ~/Library/Application\ Support/minecraft/launcher_cef_log.txt
  if [ -d ~/Library/Application\ Support/minecraft/.mixin.out ]; then
    collect_paths ~/Library/Application\ Support/minecraft/.mixin.out
  fi
  msg 'Clearing Minecraft Cache and Log Files...'
  remove_paths
fi

# Deletes Lunar Client logs (Minecraft alternate client)
# -Astro
if [ -d ~/.lunarclient ]; then
  collect_paths ~/.lunarclient/game-cache
  collect_paths ~/.lunarclient/launcher-cache
  collect_paths ~/.lunarclient/logs
  collect_paths ~/.lunarclient/offline/*/logs
  collect_paths ~/.lunarclient/offline/files/*/logs
  msg 'Deleting Lunar Client logs and caches...'
  remove_paths
fi

# Deletes Wget logs
# -Astro
if [ -d ~/wget-log ]; then
  collect_paths ~/wget-log
  collect_paths ~/.wget-hsts
  msg 'Deleting Wget log and hosts file...'
  remove_paths
fi

# Deletes Cacher logs
# I dunno either
# -Astro
if [ -d ~/.cacher ]; then
  collect_paths ~/.cacher/logs
  msg 'Deleting Cacher logs...'
  remove_paths
fi

# Deletes Android (studio?) cache
# -Astro
if [ -d ~/.android ]; then
  collect_paths ~/.android/cache
  msg 'Deleting Android cache...'
  remove_paths
fi

# Clears Gradle caches
# -Astro
if [ -d ~/.gradle ]; then
  collect_paths ~/.gradle/caches
  msg 'Clearing Gradle caches...'
  remove_paths
fi

# Deletes Kite Autocomplete logs
# -Astro
if [ -d ~/.kite ]; then
  collect_paths ~/.kite/logs
  msg 'Deleting Kite logs...'
  remove_paths
fi

if type "brew" &>/dev/null; then
  if [ "$update" = true ]; then
    msg 'Updating Homebrew Recipes...'
    brew update &>/dev/null
    msg 'Upgrading and removing outdated formulae...'
    brew upgrade &>/dev/null
  fi
  collect_paths "$(brew --cache)"
  msg 'Cleaning up Homebrew Cache...'
  if [ -z "$dry_run" ]; then
    brew cleanup -s &>/dev/null
    remove_paths
    brew tap --repair &>/dev/null
  else
    remove_paths
  fi
fi

if type "gem" &>/dev/null; then  # TODO add count_dry
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up any old versions of gems'
    gem cleanup &>/dev/null
  fi
fi

if type "docker" &>/dev/null; then  # TODO add count_dry
  if [ -z "$dry_run" ]; then
    if ! docker ps >/dev/null 2>&1; then
      close_docker=true
      open --background -a Docker
    fi
    msg 'Cleaning up Docker'
    docker system prune -af --volumes &>/dev/null
    docker builder prune -af &>/dev/null
    if [ "$close_docker" = true ]; then
      killall Docker
    fi
  fi
fi

# Shrink Docker.raw VM disk by deleting and letting Docker Desktop recreate.
# WARNING: removes all Docker images, containers, volumes, and build cache.
if [ -f ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw ]; then
  if [ -z "$dry_run" ]; then
    msg 'Shrinking Docker.raw (full reset of Docker Desktop VM disk)...'
    osascript -e 'tell application "Docker" to quit' &>/dev/null
    killall Docker &>/dev/null
    killall com.docker.backend &>/dev/null
    killall com.docker.virtualization &>/dev/null
    sleep 3
    rm -f ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw
  else
    collect_paths ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw
  fi
fi

# Xamarin Android SDK (re-downloaded by Visual Studio / Rider on demand)
if [ -d ~/Library/Developer/Xamarin/android-sdk-macosx ]; then
  collect_paths ~/Library/Developer/Xamarin/android-sdk-macosx
  msg 'Removing Xamarin Android SDK...'
  remove_paths
fi

if [ "$PYENV_VIRTUALENV_CACHE_PATH" ]; then
  collect_paths "$PYENV_VIRTUALENV_CACHE_PATH"
  msg 'Removing Pyenv-VirtualEnv Cache...'
  remove_paths
fi

if type "npm" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up npm cache...'
    npm cache clean --force &>/dev/null
  else
    collect_paths ~/.npm/*
  fi
fi

#if type "yarn" &>/dev/null; then
#  if [ -z "$dry_run" ]; then
#    msg 'Cleaning up Yarn Cache...'
#    yarn cache clean --force &>/dev/null
#  else
#    collect_paths ~/Library/Caches/yarn
#  fi
#fi

if type "pnpm" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up pnpm Cache...'
    pnpm store prune &>/dev/null
  else
    collect_paths ~/.pnpm-store/*
  fi
fi

if type "pod" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up Pod Cache...'
    pod cache clean --all &>/dev/null
  else
    collect_paths ~/Library/Caches/CocoaPods
  fi
fi

if type "go" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Clearing Go module cache...'
    go clean -modcache &>/dev/null
  else
    if [ -n "$GOPATH" ]; then
      collect_paths "$GOPATH/pkg/mod"
    else
      collect_paths ~/go/pkg/mod
    fi
  fi
fi

# Deletes all Microsoft Teams Caches and resets it to default - can fix also some performance issues
# -Astro
if [ -d ~/Library/Application\ Support/Microsoft/Teams ]; then
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/IndexedDB
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/Cache
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/Application\ Cache
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/Code\ Cache
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/blob_storage
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/databases
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/gpucache
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/Local\ Storage
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/tmp
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/*logs*.txt
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/watchdog
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/*watchdog*.json
  msg 'Deleting Microsoft Teams logs and caches...'
  remove_paths
fi

# Deletes Poetry cache
if [ -d ~/Library/Caches/pypoetry ]; then
  collect_paths ~/Library/Caches/pypoetry
  msg 'Deleting Poetry cache...'
  remove_paths
fi

# Removes Java heap dumps
collect_paths ~/*.hprof
msg 'Deleting Java heap dumps...'
remove_paths

# Chromium / Chrome cache sweep across all profiles
if [ -d ~/Library/Application\ Support/Google/Chrome/ ]; then
  collect_paths ~/Library/Application\ Support/Google/Chrome/*/Cache/*
  collect_paths ~/Library/Application\ Support/Google/Chrome/*/Code\ Cache/*
  collect_paths ~/Library/Application\ Support/Google/Chrome/*/GPUCache/*
  collect_paths ~/Library/Application\ Support/Google/Chrome/*/Service\ Worker/CacheStorage/*
  collect_paths ~/Library/Application\ Support/Google/Chrome/*/Service\ Worker/ScriptCache/*
  collect_paths ~/Library/Application\ Support/Google/Chrome/*/DawnCache/*
  collect_paths ~/Library/Application\ Support/Google/Chrome/*/DawnGraphiteCache/*
  collect_paths ~/Library/Application\ Support/Google/Chrome/*/DawnWebGPUCache/*
  collect_paths ~/Library/Application\ Support/Google/Chrome/GrShaderCache/*
  collect_paths ~/Library/Application\ Support/Google/Chrome/ShaderCache/*
  msg 'Clearing Chrome cache files (all profiles)...'
  remove_paths
fi

# VS Code caches
if [ -d ~/Library/Application\ Support/Code/ ]; then
  collect_paths ~/Library/Application\ Support/Code/Cache/*
  collect_paths ~/Library/Application\ Support/Code/Code\ Cache/*
  collect_paths ~/Library/Application\ Support/Code/CachedData/*
  collect_paths ~/Library/Application\ Support/Code/CachedExtensionVSIXs/*
  collect_paths ~/Library/Application\ Support/Code/GPUCache/*
  collect_paths ~/Library/Application\ Support/Code/logs/*
  msg 'Clearing VS Code caches and logs...'
  remove_paths
fi

# JetBrains IDE caches
if [ -d ~/Library/Caches/JetBrains/ ]; then
  collect_paths ~/Library/Caches/JetBrains/*/caches/*
  collect_paths ~/Library/Caches/JetBrains/*/index/*
  collect_paths ~/Library/Caches/JetBrains/*/log/*
  msg 'Clearing JetBrains IDE caches...'
  remove_paths
fi

# Slack (sandboxed)
if [ -d ~/Library/Containers/com.tinyspeck.slackmacgap/ ]; then
  collect_paths ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application\ Support/Slack/Cache/*
  collect_paths ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application\ Support/Slack/Code\ Cache/*
  collect_paths ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application\ Support/Slack/GPUCache/*
  collect_paths ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application\ Support/Slack/Service\ Worker/CacheStorage/*
  collect_paths ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application\ Support/Slack/Service\ Worker/ScriptCache/*
  collect_paths ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application\ Support/Slack/DawnCache/*
  collect_paths ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application\ Support/Slack/DawnGraphiteCache/*
  collect_paths ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application\ Support/Slack/DawnWebGPUCache/*
  collect_paths ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application\ Support/Slack/logs/*
  msg 'Clearing Slack caches and logs...'
  remove_paths
fi

# Microsoft Teams (new client)
if [ -d ~/Library/Containers/com.microsoft.teams2/ ]; then
  collect_paths ~/Library/Containers/com.microsoft.teams2/Data/Library/Application\ Support/Microsoft/MSTeams/Cache/*
  collect_paths ~/Library/Containers/com.microsoft.teams2/Data/Library/Application\ Support/Microsoft/MSTeams/Code\ Cache/*
  collect_paths ~/Library/Containers/com.microsoft.teams2/Data/Library/Application\ Support/Microsoft/MSTeams/GPUCache/*
  collect_paths ~/Library/Containers/com.microsoft.teams2/Data/Library/Application\ Support/Microsoft/MSTeams/Service\ Worker/CacheStorage/*
  collect_paths ~/Library/Containers/com.microsoft.teams2/Data/Library/Application\ Support/Microsoft/MSTeams/Service\ Worker/ScriptCache/*
  collect_paths ~/Library/Containers/com.microsoft.teams2/Data/Library/Application\ Support/Microsoft/MSTeams/logs/*
  collect_paths ~/Library/Containers/com.microsoft.teams2/Data/Library/Application\ Support/Microsoft/MSTeams/tmp/*
  msg 'Clearing new Microsoft Teams caches and logs...'
  remove_paths
fi

# Discord
if [ -d ~/Library/Application\ Support/discord/ ]; then
  collect_paths ~/Library/Application\ Support/discord/Cache/*
  collect_paths ~/Library/Application\ Support/discord/Code\ Cache/*
  collect_paths ~/Library/Application\ Support/discord/GPUCache/*
  collect_paths ~/Library/Application\ Support/discord/Service\ Worker/CacheStorage/*
  collect_paths ~/Library/Application\ Support/discord/Service\ Worker/ScriptCache/*
  msg 'Clearing Discord caches...'
  remove_paths
fi

# Firefox
if [ -d ~/Library/Application\ Support/Firefox/Profiles/ ]; then
  collect_paths ~/Library/Application\ Support/Firefox/Profiles/*/cache2/*
  collect_paths ~/Library/Application\ Support/Firefox/Profiles/*/startupCache/*
  collect_paths ~/Library/Application\ Support/Firefox/Profiles/*/thumbnails/*
  collect_paths ~/Library/Application\ Support/Firefox/Profiles/*/shader-cache/*
  collect_paths ~/Library/Application\ Support/Firefox/Profiles/*/storage/default/*/cache/*
  collect_paths ~/Library/Caches/Firefox/*
  msg 'Clearing Firefox caches...'
  remove_paths
fi

# Postman
if [ -d ~/Library/Application\ Support/Postman/ ]; then
  collect_paths ~/Library/Application\ Support/Postman/Cache/*
  collect_paths ~/Library/Application\ Support/Postman/Code\ Cache/*
  collect_paths ~/Library/Application\ Support/Postman/GPUCache/*
  collect_paths ~/Library/Application\ Support/Postman/IndexedDB/*
  collect_paths ~/Library/Application\ Support/Postman/logs/*
  msg 'Clearing Postman caches and logs...'
  remove_paths
fi

# Spotify
if [ -d ~/Library/Application\ Support/Spotify/PersistentCache/ ]; then
  collect_paths ~/Library/Application\ Support/Spotify/PersistentCache/*
  msg 'Clearing Spotify persistent cache...'
  remove_paths
fi

# Blanket sandboxed app caches
if [ -d ~/Library/Containers/ ]; then
  collect_paths ~/Library/Containers/*/Data/Library/Caches/*
  msg 'Clearing sandboxed app caches...'
  remove_paths
fi

# HTTPStorages and WebKit website data
collect_paths ~/Library/HTTPStorages/*/*Cache*
collect_paths ~/Library/WebKit/*/WebsiteData/*
msg 'Clearing HTTPStorages and WebKit website data...'
remove_paths

# Saved application state (window positions)
collect_paths ~/Library/Saved\ Application\ State/*
msg 'Clearing saved application state...'
remove_paths

# QuickLook thumbnail cache
if [ -z "$dry_run" ]; then
  msg 'Resetting QuickLook thumbnail cache...'
  qlmanage -r cache &>/dev/null
fi

# Time Machine local snapshots (frequent System Data culprit)
if [ -z "$dry_run" ] && type "tmutil" &>/dev/null; then
  msg 'Deleting Time Machine local snapshots...'
  for snap in $(tmutil listlocalsnapshotdates / 2>/dev/null | grep -E '^[0-9]'); do
    sudo tmutil deletelocalsnapshots "$snap" &>/dev/null
  done
fi

# Unified system logs (/private/var/db/diagnostics)
if [ -z "$dry_run" ]; then
  msg 'Erasing unified system logs...'
  sudo log erase --all &>/dev/null
fi

# Periodic maintenance scripts
if [ -z "$dry_run" ]; then
  msg 'Running periodic maintenance (daily, weekly, monthly)...'
  sudo periodic daily weekly monthly &>/dev/null
fi

# Mail downloads (attachments cached on open)
if [ -d ~/Library/Containers/com.apple.mail/Data/Library/Mail\ Downloads/ ]; then
  collect_paths ~/Library/Containers/com.apple.mail/Data/Library/Mail\ Downloads/*
  msg 'Clearing Mail attachment downloads...'
  remove_paths
fi

# Old iOS device support files (re-downloaded on demand)
if [ -d ~/Library/Developer/Xcode/iOS\ DeviceSupport/ ]; then
  collect_paths ~/Library/Developer/Xcode/iOS\ DeviceSupport/*
  msg 'Removing old iOS device support files...'
  remove_paths
fi

if [ -z "$dry_run" ]; then
  msg 'Cleaning up DNS cache...'
  sudo dscacheutil -flushcache &>/dev/null
  sudo killall -HUP mDNSResponder &>/dev/null
fi

if [ -z "$dry_run" ]; then
  msg 'Purging inactive memory...'
  sudo purge &>/dev/null
fi

# Disables extended regex
shopt -u extglob

# Optional report-regen tasks
if [ -z "$dry_run" ]; then
  [ "$thin_snapshots" = true ] && thin_local_snapshots
  [ "$rebuild_index" = true ] && rebuild_storage_index
fi

# Build flag list for re-exec after dry-run confirmation
rerun_flags=()
[ "$update" = true ] && rerun_flags+=(--update)
[ "$thin_snapshots" = true ] && rerun_flags+=(--thin-snapshots)
[ "$rebuild_index" = true ] && rerun_flags+=(--rebuild-index)

if [ -z "$dry_run" ]; then
  msg "${GREEN}Success!${NOFORMAT}"

  newAvailable=$(df / | tail -1 | awk '{print $4}')
  count=$((newAvailable - oldAvailable))
  bytesToHuman $count
  cleanup
else
  count_dry
  unset dry_run
  bytesToHuman "$dry_results"
  msg "Continue? [enter]"
  read -r -s -n 1 clean_dry_run
  if [[ $clean_dry_run = "" ]]; then
    exec "$0" "${rerun_flags[@]}"
  fi
  cleanup
fi