# Colors
# ANSI-C quoting ($'...') bakes the real ESC byte at assignment time, so the codes
# render regardless of how a given `echo`/`-e` interprets backslash escapes. Storing
# literal "\033[..." strings breaks on shells whose echo does not expand them (Windows),
# where the codes then print as text.
export COL_RED=$'\033[1;31m'
export COL_GREEN=$'\033[0;32m'
export COL_YELLOW=$'\033[33m'
export COL_BLUE=$'\033[34m'
export COL_MAGENTA=$'\033[35m'
export COL_CYAN=$'\033[36m'

# Reset color
export COL_RESET=$'\033[0m'