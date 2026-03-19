#!/bin/bash

# Logging functions with localized color definitions

# Local color definitions
COL_RED="\033[1;31m"
COL_GREEN="\033[0;32m"
COL_YELLOW="\x1b[33m"
COL_BLUE="\x1b[34m"
COL_MAGENTA="\x1b[35m"
COL_CYAN="\x1b[36m"
COL_RESET="\033[0m"

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