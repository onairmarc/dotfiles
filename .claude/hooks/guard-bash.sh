#!/usr/bin/env bash
# PreToolUse guard for the Bash tool.
#
# Claude Code pipes a JSON blob describing the tool call to this script's stdin.
# We pull out the command string and match it against a table of blocked patterns.
# On a match we print a deny decision to stdout and Claude refuses to run it.
# On no match we print nothing and exit 0, which lets the command through.
#
# To add a rule: append a "pattern|||reason" line to the RULES array below.
# Test a command without Claude:  echo '{"tool_input":{"command":"git push"}}' | .claude/hooks/guard-bash.sh
set -euo pipefail

# The command the model wants to run. Falls back to empty string if absent.
cmd="$(jq -r '.tool_input.command // ""')"

# Each entry: <extended-regex> ||| <reason shown to Claude when blocked>.
# Patterns use (^|[^[:alnum:]_]) as a left word-boundary so "mygit" won't match "git".
RULES=(
  # Commands that can discard uncommitted or untracked work.
  '(^|[^[:alnum:]_])git[[:space:]]+((checkout|reset|clean|restore)([[:space:]]|$)|stash[[:space:]]+(drop|clear)([[:space:]]|$)|switch[[:space:]][^&|;]*(-f([[:space:]]|$)|--force|--discard-changes))|||Blocked: this git command can discard uncommitted or untracked work (checkout, reset, clean, restore, stash drop/clear, switch --force). Save with git stash first, or run it yourself with the ! prefix if intended.'

  # Outward-facing publish commands.
  '(^|[^[:alnum:]_])(git[[:space:]]+push([[:space:]]|$)|gh[[:space:]]+(pr[[:space:]]+(create|edit|merge|ready|comment)|issue[[:space:]]+(create|edit|comment)|release[[:space:]]+create)([[:space:]]|$))|||Blocked: outward-facing publish command (git push; gh pr/issue create, edit, comment; gh pr merge/ready; gh release create). Run it yourself with the ! prefix if you intend to publish.'
)

for rule in "${RULES[@]}"; do
  pattern="${rule%%|||*}"
  reason="${rule##*|||}"
  if printf '%s' "$cmd" | grep -qE "$pattern"; then
    # jq builds the decision JSON so the reason is safely escaped.
    jq -cn --arg reason "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
  fi
done

exit 0
