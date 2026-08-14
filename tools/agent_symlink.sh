#!/usr/bin/env bash
#
# Recreates skill symlinks from the source of truth (.agents/skills/)
# to the target directories (.claude/skills and ~/.claude/skills)
#
# Skills are organized into domain subdirectories under .agents/skills/
# (e.g. .agents/skills/planning/feature-planning/). Regardless of how deep a
# skill lives in the source tree, it is deployed FLAT: each skill directory is
# symlinked by its own name directly into the target skills directory, so the
# consumer always sees ~/.claude/skills/<skill-name>/SKILL.md.
#
# Usage: agent_symlink [--global]
#
# Options:
#   --global    Create symlinks from ~/.claude/skills to this repo's .agents/skills
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

# Link every skill under a source root FLAT into a target directory.
#
# A "skill" is any directory containing a SKILL.md, at any depth beneath the
# source root. Each such directory is symlinked into the target by its own
# basename, so the domain subdirectory it lives in is collapsed away. On a name
# collision the later caller wins (the existing link is removed and replaced),
# which lets private skills override public ones when linked afterwards.
#
# Args: <source_root> <target_dir> [label]
link_skills_flat() {
    local source_root="$1"
    local target_dir="$2"
    local label="$3"
    local skill_md skill_path skill_name

    while IFS= read -r -d '' skill_md; do
        skill_path="$(dirname "$skill_md")"
        skill_name="$(basename "$skill_path")"

        if [[ -L "$target_dir/$skill_name" ]] || [[ -e "$target_dir/$skill_name" ]]; then
            log_warn "  Skill collision on '$skill_name': ${label:-later} wins, overriding earlier"
            rm -rf "$target_dir/$skill_name"
        fi

        ln -s "$skill_path" "$target_dir/$skill_name"
        log_info "  Linked ${label:+$label }skill: $skill_name"
    done < <(find "$source_root" -name "SKILL.md" -type f -print0)
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

    # 1. Link ~/.claude/skills <- .agents/skills (interleave with dotfiles-private if present)
    SKILLS_TARGET="$CLAUDE_DIR/skills"
    SKILLS_SOURCE="$REPO_ROOT/.agents/skills"

    if [[ ! -d "$SKILLS_SOURCE" ]]; then
        log_error "Source directory does not exist: $SKILLS_SOURCE"
        exit 1
    fi

    # The target is always a real directory populated with per-skill symlinks, so
    # remove any prior directory or symlink and recreate it fresh.
    if [[ -e "$SKILLS_TARGET" ]] || [[ -L "$SKILLS_TARGET" ]]; then
        log_info "  Removing existing: $SKILLS_TARGET"
        rm -rf "$SKILLS_TARGET"
    fi
    mkdir -p "$SKILLS_TARGET"

    # Resolve private dotfiles location (env var preferred, default fallback)
    PRIVATE_DIR="${DF_PRIVATE_DIRECTORY:-$HOME/Documents/GitHub/dotfiles-private}"
    PRIVATE_SKILLS_SOURCE="$PRIVATE_DIR/.agents/skills"

    if [[ -d "$PRIVATE_SKILLS_SOURCE" ]]; then
        log_info "Global mode: interleaving public + private skills into $SKILLS_TARGET"
        log_info "  Public:  $SKILLS_SOURCE"
        log_info "  Private: $PRIVATE_SKILLS_SOURCE"

        # Link public skills first, then private; private wins on collision.
        link_skills_flat "$SKILLS_SOURCE" "$SKILLS_TARGET" "public"
        link_skills_flat "$PRIVATE_SKILLS_SOURCE" "$SKILLS_TARGET" "private"
    else
        log_info "Global mode: linking public skills into $SKILLS_TARGET"
        log_info "  (no private dotfiles found at $PRIVATE_DIR)"

        link_skills_flat "$SKILLS_SOURCE" "$SKILLS_TARGET" ""
    fi

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

# Default (in-repo) mode.
#
# 1. Populate .claude/skills with flat per-skill symlinks into .agents/skills.
#    A wholesale directory symlink is not used because the source is organized
#    into domain subdirectories that must be collapsed away for the consumer.
LOCAL_SKILLS_TARGET="$REPO_ROOT/.claude/skills"
LOCAL_SKILLS_SOURCE="$REPO_ROOT/.agents/skills"

if [[ ! -d "$LOCAL_SKILLS_SOURCE" ]]; then
    log_warn "Skipping .claude/skills: source does not exist ($LOCAL_SKILLS_SOURCE)"
else
    log_info "Populating $LOCAL_SKILLS_TARGET with per-skill symlinks"

    if [[ -e "$LOCAL_SKILLS_TARGET" ]] || [[ -L "$LOCAL_SKILLS_TARGET" ]]; then
        log_info "  Removing existing: $LOCAL_SKILLS_TARGET"
        rm -rf "$LOCAL_SKILLS_TARGET"
    fi
    mkdir -p "$LOCAL_SKILLS_TARGET"

    link_skills_flat "$LOCAL_SKILLS_SOURCE" "$LOCAL_SKILLS_TARGET" ""
fi

# 2. Link CLAUDE.md -> AGENTS.md at the repo root.
CLAUDE_MD_TARGET="$REPO_ROOT/CLAUDE.md"
AGENTS_MD_SOURCE="$REPO_ROOT/AGENTS.md"

if [[ ! -e "$AGENTS_MD_SOURCE" ]]; then
    log_warn "Skipping CLAUDE.md: source does not exist (AGENTS.md)"
else
    log_info "Creating symlink: $CLAUDE_MD_TARGET -> AGENTS.md"

    if [[ -e "$CLAUDE_MD_TARGET" ]] || [[ -L "$CLAUDE_MD_TARGET" ]]; then
        log_info "  Removing existing: $CLAUDE_MD_TARGET"
        rm -rf "$CLAUDE_MD_TARGET"
    fi

    pushd "$REPO_ROOT" > /dev/null
    ln -s "AGENTS.md" "CLAUDE.md"
    popd > /dev/null

    log_info "  Created symlink"
fi

log_info "Sync complete!"
