#!/bin/bash

# Logging functions with localized color definitions

# Local color definitions
# ANSI-C quoting ($'...') bakes the real ESC byte at assignment time so colors render
# regardless of how the current shell's echo handles backslash escapes.
COL_RED=$'\033[1;31m'
COL_GREEN=$'\033[0;32m'
COL_YELLOW=$'\033[33m'
COL_BLUE=$'\033[34m'
COL_MAGENTA=$'\033[35m'
COL_CYAN=$'\033[36m'
COL_RESET=$'\033[0m'

log_info() {
    echo -e "${COL_BLUE}$*${COL_RESET}"
}

log_success() {
    echo -e "${COL_GREEN}$*${COL_RESET}"
}

log_warning() {
    echo -e "${COL_YELLOW}$*${COL_RESET}"
}

log_error() {
    echo -e "${COL_RED}$*${COL_RESET}"
}

log_debug() {
    echo -e "${COL_MAGENTA}$*${COL_RESET}"
}

log_note() {
    echo -e "${COL_CYAN}$*${COL_RESET}"
}

log_plain() {
    echo -e "$*"
}