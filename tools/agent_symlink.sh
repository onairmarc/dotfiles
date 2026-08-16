#!/usr/bin/env bash
#
# Recreates skill symlinks from the source of truth (.agents/skills/)
# to the target directories (.claude/skills and ~/.claude/skills).
# When --global is used and OpenCode is installed, also populates
# ~/.config/opencode/skills.
#
# Skills are organized into domain subdirectories under .agents/skills/
# (e.g. .agents/skills/planning/feature-planning/). Regardless of how deep a
# skill lives in the source tree, it is deployed FLAT: each skill directory is
# symlinked by its own name directly into the target skills directory, so the
# consumer always sees ~/.claude/skills/<skill-name>/SKILL.md (and, when
# OpenCode is present, ~/.config/opencode/skills/<skill-name>/SKILL.md).
#
# Usage: agent_symlink [--global]
#
# Options:
#   --global    Create symlinks from ~/.claude/skills to this repo's .agents/skills.
#               If OpenCode is installed, also symlink into ~/.config/opencode/skills.
#               May be run from any directory on the filesystem: the dotfiles repo
#               root is resolved from this script's own location, the work runs
#               there, and the caller's working directory is restored on exit.
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

# True when the OpenCode CLI is on PATH or at the installer's default location
# (~/.opencode/bin/opencode), which this repo's provisioner uses.
opencode_is_installed() {
    command -v opencode >/dev/null 2>&1 || [[ -x "$HOME/.opencode/bin/opencode" ]]
}

# Recreate a target skills directory and populate it with flat per-skill
# symlinks. Public skills are linked first; private skills override on collision.
#
# Args: <target_dir> <public_source> <label> [private_source] [private_dir]
populate_skills_target() {
    local target_dir="$1"
    local public_source="$2"
    local label="$3"
    local private_source="$4"
    local private_dir="$5"

    if [[ -e "$target_dir" ]] || [[ -L "$target_dir" ]]; then
        log_info "  Removing existing: $target_dir"
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"

    if [[ -n "$private_source" && -d "$private_source" ]]; then
        log_info "${label}: interleaving public + private skills into $target_dir"
        log_info "  Public:  $public_source"
        log_info "  Private: $private_source"

        link_skills_flat "$public_source" "$target_dir" "public"
        link_skills_flat "$private_source" "$target_dir" "private"
    else
        log_info "${label}: linking public skills into $target_dir"
        if [[ -n "$private_dir" ]]; then
            log_info "  (no private dotfiles found at $private_dir)"
        fi

        link_skills_flat "$public_source" "$target_dir" ""
    fi
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

# Ensure we return to original directory on exit, so all navigation below is
# transparent to the caller regardless of where they invoked the script from.
cleanup() {
    cd "$ORIGINAL_DIR"
}
trap cleanup EXIT

# Resolve this script's real directory, following symlinks (the script may be
# invoked through a symlink on PATH). macOS `readlink` has no `-f`, so walk the
# symlink chain manually for portability.
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_SOURCE" ]]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" > /dev/null 2>&1 && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ "$SCRIPT_SOURCE" != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" > /dev/null 2>&1 && pwd)"

# The script lives at <dotfiles>/tools/agent_symlink.sh, so its parent's parent
# is the dotfiles repo root.
DOTFILES_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ "$GLOBAL_MODE" == true ]]; then
    # Global mode targets the dotfiles repo itself, located via the script path
    # rather than the caller's CWD — so it works from anywhere on the filesystem.
    REPO_ROOT="$DOTFILES_ROOT"
else
    # Default and recursive modes operate on the current repository.
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository. Please run this script from within a git repo."
        exit 1
    fi
    REPO_ROOT="$(git rev-parse --show-toplevel)"
fi

# Navigate to the repo root to run the rest of the script. The EXIT trap above
# restores the caller's directory, keeping this move invisible to them.
if [[ "$ORIGINAL_DIR" != "$REPO_ROOT" ]]; then
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

    # Resolve private dotfiles location (env var preferred, default fallback)
    PRIVATE_DIR="${DF_PRIVATE_DIRECTORY:-$HOME/Documents/GitHub/dotfiles-private}"
    PRIVATE_SKILLS_SOURCE="$PRIVATE_DIR/.agents/skills"

    populate_skills_target "$SKILLS_TARGET" "$SKILLS_SOURCE" "Global mode" \
        "$PRIVATE_SKILLS_SOURCE" "$PRIVATE_DIR"

    # 1b. If OpenCode is installed, also flatten into its global skills directory.
    if opencode_is_installed; then
        OPENCODE_SKILLS_TARGET="$HOME/.config/opencode/skills"
        populate_skills_target "$OPENCODE_SKILLS_TARGET" "$SKILLS_SOURCE" "OpenCode" \
            "$PRIVATE_SKILLS_SOURCE" "$PRIVATE_DIR"
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
