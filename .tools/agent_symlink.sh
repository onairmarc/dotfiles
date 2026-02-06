#!/usr/bin/env bash
#
# Recreates skill symlinks from the source of truth (.agents/skills/)
# to the target directories (.claude/skills and .github/skills)
#
# Usage: ./bin/symlink.sh
#
# Note: On Windows, requires Developer Mode enabled or Administrator privileges

set -e

# Colors for output (defined early for use in validation)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Save original directory to return to later
ORIGINAL_DIR="$(pwd)"

# Ensure we return to original directory on exit
cleanup() {
    cd "$ORIGINAL_DIR"
}
trap cleanup EXIT

# Verify we are in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not in a git repository. Please run this script from within a git repo."
    exit 1
fi

# Get the repo root and navigate to it
REPO_ROOT="$(git rev-parse --show-toplevel)"

if [[ "$ORIGINAL_DIR" != "$REPO_ROOT" ]]; then
    log_info "Navigating to repo root: $REPO_ROOT"
    cd "$REPO_ROOT"
fi

# Target symlinks and their relative paths to source
declare -A TARGETS=(
    ["$REPO_ROOT/.claude/skills"]="../.agents/skills"
    ["$REPO_ROOT/.github/skills"]="../.agents/skills"
    ["$REPO_ROOT/CLAUDE.md"]="AGENTS.md"
)

# Detect OS
is_windows() {
    [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]
}

if is_windows; then
    log_info "Detected Windows - using mklink /D for directory symlinks"
fi

for TARGET in "${!TARGETS[@]}"; do
    RELATIVE_SOURCE="${TARGETS[$TARGET]}"
    PARENT_DIR="$(dirname "$TARGET")"
    LINK_NAME="$(basename "$TARGET")"

    # Resolve full source path to verify it exists
    FULL_SOURCE="$PARENT_DIR/$RELATIVE_SOURCE"

    # Verify source exists before creating symlink
    if [[ ! -e "$FULL_SOURCE" ]]; then
        log_warn "Skipping $LINK_NAME: source does not exist ($RELATIVE_SOURCE)"
        continue
    fi

    log_info "Creating symlink: $TARGET -> $RELATIVE_SOURCE"

    # Remove existing target if it exists (file, directory, or symlink)
    if [[ -e "$TARGET" ]] || [[ -L "$TARGET" ]]; then
        log_info "  Removing existing: $TARGET"
        rm -rf "$TARGET"
    fi

    # Ensure parent directory exists
    mkdir -p "$PARENT_DIR"

    # Determine if source is a directory (for Windows mklink flag)
    IS_DIR=false
    if [[ -d "$FULL_SOURCE" ]]; then
        IS_DIR=true
    fi

    # Create symlink from parent directory
    pushd "$PARENT_DIR" > /dev/null

    if is_windows; then
        WIN_RELATIVE_SOURCE="${RELATIVE_SOURCE//\//\\}"
        if [[ "$IS_DIR" == true ]]; then
            cmd //c "mklink /D $LINK_NAME $WIN_RELATIVE_SOURCE" > /dev/null
        else
            cmd //c "mklink $LINK_NAME $WIN_RELATIVE_SOURCE" > /dev/null
        fi
    else
        ln -s "$RELATIVE_SOURCE" "$LINK_NAME"
    fi

    popd > /dev/null

    log_info "  Created symlink"
done

log_info "Sync complete!"
