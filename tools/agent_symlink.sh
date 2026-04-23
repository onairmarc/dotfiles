#!/usr/bin/env bash
#
# Recreates skill symlinks from the source of truth (.agents/skills/)
# to the target directories (.claude/skills and .github/skills)
#
# Usage: agent_symlink [--global]
#
# Options:
#   --global    Create symlink from ~/.claude/skills to this repo's .agents/skills
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

# Parse command line arguments
GLOBAL_MODE=false
RECURSIVE_MODE=false
for arg in "$@"; do
    case $arg in
        --global)
            GLOBAL_MODE=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE_MODE=true
            shift
            ;;
        *)
            log_error "Unknown option: $arg"
            echo "Usage: $0 [--global] [-r]"
            exit 1
            ;;
    esac
done

if [[ "$GLOBAL_MODE" == true && "$RECURSIVE_MODE" == true ]]; then
    log_error "--global and -r cannot be used together"
    echo "Usage: $0 [--global] [-r]"
    exit 1
fi

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

# Detect OS
is_windows() {
    [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]
}

if is_windows; then
    log_info "Detected Windows - using native symlinks"
    export MSYS=winsymlinks:nativestrict
fi

# Handle global mode: link ~/.claude/skills and ~/.claude/CLAUDE.md to this repo's .agents/
if [[ "$GLOBAL_MODE" == true ]]; then
    CLAUDE_DIR="$HOME/.claude"

    # Ensure parent directory exists
    mkdir -p "$CLAUDE_DIR"

    # 1. Link ~/.claude/skills -> .agents/skills
    SKILLS_TARGET="$CLAUDE_DIR/skills"
    SKILLS_SOURCE="$REPO_ROOT/.agents/skills"

    if [[ ! -d "$SKILLS_SOURCE" ]]; then
        log_error "Source directory does not exist: $SKILLS_SOURCE"
        exit 1
    fi

    log_info "Global mode: Creating symlink from ~/.claude/skills to $SKILLS_SOURCE"

    if [[ -e "$SKILLS_TARGET" ]] || [[ -L "$SKILLS_TARGET" ]]; then
        log_info "  Removing existing: $SKILLS_TARGET"
        rm -rf "$SKILLS_TARGET"
    fi

    ln -s "$SKILLS_SOURCE" "$SKILLS_TARGET"
    log_info "  Created global symlink: $SKILLS_TARGET -> $SKILLS_SOURCE"

    # 2. Link ~/.claude/CLAUDE.md -> .agents/AGENTS.md
    CLAUDE_MD_TARGET="$CLAUDE_DIR/CLAUDE.md"
    AGENTS_MD_SOURCE="$REPO_ROOT/.agents/AGENTS.md"

    if [[ ! -f "$AGENTS_MD_SOURCE" ]]; then
        log_warn "Source file does not exist, skipping: $AGENTS_MD_SOURCE"
    else
        log_info "Global mode: Creating symlink from ~/.claude/CLAUDE.md to $AGENTS_MD_SOURCE"

        if [[ -e "$CLAUDE_MD_TARGET" ]] || [[ -L "$CLAUDE_MD_TARGET" ]]; then
            log_info "  Removing existing: $CLAUDE_MD_TARGET"
            rm -f "$CLAUDE_MD_TARGET"
        fi

        ln -s "$AGENTS_MD_SOURCE" "$CLAUDE_MD_TARGET"
        log_info "  Created global symlink: $CLAUDE_MD_TARGET -> $AGENTS_MD_SOURCE"
    fi

    log_info "Sync complete!"
    exit 0
fi

# Handle recursive mode: link CLAUDE.md -> AGENTS.md in every dir that has AGENTS.md
if [[ "$RECURSIVE_MODE" == true ]]; then
    log_info "Recursive mode: scanning for AGENTS.md files under $(pwd)"
    found=0
    skipped=0
    while IFS= read -r -d '' agents_file; do
        dir="$(dirname "$agents_file")"
        claude_file="$dir/CLAUDE.md"

        if [[ -e "$claude_file" ]] || [[ -L "$claude_file" ]]; then
            log_warn "  Skipping $claude_file: already exists"
            ((skipped++)) || true
            continue
        fi

        ln -s "AGENTS.md" "$claude_file"
        log_info "  Created symlink: $claude_file -> AGENTS.md"
        ((found++)) || true
    done < <(find "$(pwd)" -name "AGENTS.md" -print0)

    log_info "Sync complete! Created $found symlink(s), skipped $skipped."
    exit 0
fi

# Define target symlinks as: "target_path|relative_source"
# This avoids complex path expansions in array keys
SYMLINK_PAIRS=(
    ".claude/skills|../.agents/skills"
    "CLAUDE.md|AGENTS.md"
)

for PAIR in "${SYMLINK_PAIRS[@]}"; do
    TARGET_PATH="${PAIR%%|*}"
    RELATIVE_SOURCE="${PAIR##*|}"

    TARGET="$REPO_ROOT/$TARGET_PATH"
    PARENT_DIR="$(dirname "$TARGET")"
    LINK_NAME="$(basename "$TARGET")"

    # Resolve full source path to verify it exists
    FULL_SOURCE="$PARENT_DIR/$RELATIVE_SOURCE"

    # Verify source exists before operating on target at all
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

    # Create symlink from parent directory
    pushd "$PARENT_DIR" > /dev/null
    ln -s "$RELATIVE_SOURCE" "$LINK_NAME"
    popd > /dev/null

    log_info "  Created symlink"
done

log_info "Sync complete!"
