#!/usr/bin/env bash
# PreToolUse guard for the Bash tool.
#
# Claude Code pipes a JSON blob describing the tool call to this script's stdin.
# We pull out the command string and match it against a set of blocked rules.
# On a match we print a deny decision to stdout and Claude refuses to run it.
# On no match we print nothing and exit 0, which lets the command through.
#
# HOW TO EDIT THE RULES
#   Each entry in RULES is a reason line, then "|||", then one phrase per line:
#
#       "Blocked: ...reason shown to Claude... |||
#         git push
#         gh pr create"
#
#   A phrase is just the command text you want to block, e.g. "git push" or
#   "gh pr create". The script automatically wraps each phrase with a word
#   boundary (so "git" won't match "mygit") and allows any whitespace between
#   words. To block a new command, add one more line -- no regex needed.
#
#   For the rare flag-based rule a literal phrase can't express, prefix the line
#   with "re:" and the remainder is used as a raw regex, verbatim.
#
# Test a command without Claude:
#   echo '{"tool_input":{"command":"git push"}}' | .claude/hooks/guard-bash.sh
set -euo pipefail

RULES=(
  "Blocked: this git command can discard uncommitted or untracked work (checkout, reset, clean, restore, stash drop/clear, switch --force). Save with git stash first, or run it yourself with the ! prefix if intended. |||
    git checkout
    git reset
    git clean
    git restore
    git stash drop
    git stash clear
    re:(^|[^[:alnum:]_])git[[:space:]]+switch[[:space:]][^&|;]*(-f([[:space:]]|$)|--force|--discard-changes)"

  "Blocked: outward-facing publish command (git push; gh pr/issue create, edit, comment; gh pr merge/ready; gh release create). Run it yourself with the ! prefix if you intend to publish. |||
    git push
    gh pr create
    gh pr edit
    gh pr merge
    gh pr ready
    gh pr comment
    gh issue create
    gh issue edit
    gh issue comment
    gh release create"
)

# The command the model wants to run. Falls back to empty string if absent.
cmd="$(jq -r '.tool_input.command // ""')"

trim() { printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }

# Turn one phrase into a regex fragment. Literal phrases get a left word
# boundary, flexible inter-word whitespace, and a trailing boundary. "re:" ones
# pass through untouched.
phrase_to_regex() {
  local p; p="$(trim "$1")"
  if [ "${p#re:}" != "$p" ]; then
    printf '%s' "${p#re:}"
  else
    p="$(printf '%s' "$p" | sed -E 's/[[:space:]]+/[[:space:]]+/g')"
    printf '(^|[^[:alnum:]_])%s([[:space:]]|$)' "$p"
  fi
}

for rule in "${RULES[@]}"; do
  reason="$(trim "${rule%%|||*}")"
  phrases="${rule#*|||}"

  regex=""
  while IFS= read -r phrase; do
    [ -z "$(trim "$phrase")" ] && continue
    frag="$(phrase_to_regex "$phrase")"
    if [ -z "$regex" ]; then regex="$frag"; else regex="$regex|$frag"; fi
  done <<< "$phrases"

  if printf '%s' "$cmd" | grep -qE "$regex"; then
    # jq builds the decision JSON so the reason is safely escaped.
    jq -cn --arg reason "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
  fi
done

exit 0
