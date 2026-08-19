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
# Usage: agent_symlink [--global] [--debug]
#
# Options:
#   --global    Create symlinks from ~/.claude/skills to this repo's .agents/skills.
#               If OpenCode is installed, also symlink into ~/.config/opencode/skills.
#               May be run from any directory on the filesystem: the dotfiles repo
#               root is resolved from this script's own location, the work runs
#               there, and the caller's working directory is restored on exit.
#   --debug     Print verbose diagnostics: one line per (skill, target) symlink,
#               plus source/target and directory-removal detail. Without it, each
#               skill logs a single line regardless of how many targets it links.
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

# Verbose diagnostics, printed only when --debug is passed. The `return 0`
# keeps `set -e` from treating a false condition as a fatal command failure.
log_debug() {
    [[ "$DEBUG_MODE" == true ]] && echo -e "${GREEN}[DEBUG]${NC} $1"
    return 0
}

# Link every skill under a source root FLAT into one or more target directories.
#
# A "skill" is any directory containing a SKILL.md, at any depth beneath the
# source root. The source tree is scanned exactly once; for each skill found,
# a symlink is created into every target directory by the skill's own basename,
# so the domain subdirectory it lives in is collapsed away. On a name collision
# within a target the later caller wins (the existing link is removed and
# replaced), which lets private skills override public ones when linked
# afterwards.
#
# Args: <source_root> <label> <target_dir>...
link_skills_flat() {
    local source_root="$1"
    local label="$2"
    shift 2
    local targets=("$@")
    local skill_md skill_path skill_name target_dir

    while IFS= read -r -d '' skill_md; do
        skill_path="$(dirname "$skill_md")"
        skill_name="$(basename "$skill_path")"

        for target_dir in "${targets[@]}"; do
            if [[ -L "$target_dir/$skill_name" ]] || [[ -e "$target_dir/$skill_name" ]]; then
                log_warn "  Skill collision on '$skill_name' in $target_dir: ${label:-later} wins, overriding earlier"
                rm -rf "$target_dir/$skill_name"
            fi

            ln -s "$skill_path" "$target_dir/$skill_name"
            log_debug "  Linked ${label:+$label }skill: $skill_name -> $target_dir"
        done

        log_info "  Linked ${label:+$label }skill: $skill_name"
    done < <(find "$source_root" -name "SKILL.md" -type f -print0)
}

# True when the OpenCode CLI is on PATH or at the installer's default location
# (~/.opencode/bin/opencode), which this repo's provisioner uses.
opencode_is_installed() {
    command -v opencode >/dev/null 2>&1 || [[ -x "$HOME/.opencode/bin/opencode" ]]
}

# Replace target with a symlink to source. Skips if source is missing.
# Args: <source> <target> <label>
link_file() {
    local source="$1"
    local target="$2"
    local label="$3"

    if [[ ! -e "$source" ]]; then
        log_warn "Source does not exist, skipping: $source"
        return 0
    fi

    mkdir -p "$(dirname "$target")"

    log_info "${label}: $target -> $source"

    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        log_info "  Removing existing: $target"
        rm -f "$target"
    fi

    ln -s "$source" "$target"
    log_info "  Created symlink: $target -> $source"
}

# Recreate one or more target skills directories and populate them with flat
# per-skill symlinks. Each source tree is scanned exactly once and fanned out to
# every target, so N targets cost one scan, not N. Public skills are linked
# first; private skills override on collision.
#
# Args: <public_source> <private_source> <private_dir> <label> <target_dir>...
populate_skills_targets() {
    local public_source="$1"
    local private_source="$2"
    local private_dir="$3"
    local label="$4"
    shift 4
    local targets=("$@")
    local target_dir

    for target_dir in "${targets[@]}"; do
        if [[ -e "$target_dir" ]] || [[ -L "$target_dir" ]]; then
            log_debug "  Removing existing: $target_dir"
            rm -rf "$target_dir"
        fi
        mkdir -p "$target_dir"
    done

    if [[ -n "$private_source" && -d "$private_source" ]]; then
        log_info "${label}: interleaving public + private skills into ${targets[*]}"
        log_debug "  Public:  $public_source"
        log_debug "  Private: $private_source"

        link_skills_flat "$public_source" "public" "${targets[@]}"
        link_skills_flat "$private_source" "private" "${targets[@]}"
    else
        log_info "${label}: linking public skills into ${targets[*]}"
        if [[ -n "$private_dir" ]]; then
            log_debug "  (no private dotfiles found at $private_dir)"
        fi

        link_skills_flat "$public_source" "" "${targets[@]}"
    fi
}

# Parse command line arguments
GLOBAL_MODE=false
RECURSIVE_MODE=false
DEBUG_MODE=false
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
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        *)
            log_error "Unknown option: $arg"
            echo "Usage: $0 [--global] [-r] [--debug]"
            exit 1
            ;;
    esac
done

if [[ "$GLOBAL_MODE" == true && "$RECURSIVE_MODE" == true ]]; then
    log_error "--global and -r cannot be used together"
    echo "Usage: $0 [--global] [-r] [--debug]"
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

    # Build the target list from the present tool conditions: ~/.claude/skills
    # is always a target; OpenCode's global skills dir joins only if installed.
    # All targets are populated from a single scan of each source tree.
    SKILL_TARGETS=("$SKILLS_TARGET")
    if opencode_is_installed; then
        SKILL_TARGETS+=("$HOME/.config/opencode/skills")
    fi

    populate_skills_targets "$SKILLS_SOURCE" "$PRIVATE_SKILLS_SOURCE" "$PRIVATE_DIR" \
        "Global mode" "${SKILL_TARGETS[@]}"

    # 2. Link ~/.claude/CLAUDE.md -> .agents/AGENTS.md
    link_file "$REPO_ROOT/.agents/AGENTS.md" "$CLAUDE_DIR/CLAUDE.md" "Global mode"

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

    link_skills_flat "$LOCAL_SKILLS_SOURCE" "" "$LOCAL_SKILLS_TARGET"
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
