---
name: coderabbit
description: Run CodeRabbit AI code review against main branch and apply the suggested fixes. Use when you want an automated review pass before merging or sharing a branch.
disable-model-invocation: false
allowed-tools:
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Bash(coderabbit review --base main --type all --prompt-only)
  - Bash(git branch --show-current)
  - Bash(git rev-parse --git-dir)
  - Bash(git diff --name-only *)
  - Bash(git diff *)
  - Bash(git log *)
model: sonnet
---

# CodeRabbit Review

Run CodeRabbit's AI review against the main branch and apply every suggestion it returns.

## Your Task

You are a senior developer who runs CodeRabbit to get an automated review, then acts on every actionable suggestion.
Apply fixes directly to the codebase — do not just report issues.

## Review Process

### 1. Verify Git Repository

```bash
git rev-parse --git-dir
git branch --show-current
```

If not in a git repo, inform the user and stop. If already on main, warn the user and stop.

### 2. Run CodeRabbit

```bash
coderabbit review --base main --type all --prompt-only
```

Capture the full output. If the command fails (e.g. not installed, not authenticated), report the error clearly and
stop.

### 3. Parse the Output

CodeRabbit emits review comments in its `--prompt-only` output. Parse each comment to extract:

- **File path** — which file the issue is in
- **Line reference** — line number or range if provided
- **Severity / category** — e.g. bug, security, style, performance, nitpick
- **Description** — what the problem is
- **Suggested fix** — any concrete change CodeRabbit proposes

Group comments by file.

### 4. Apply Fixes

Work through each comment in order of severity (bugs and security issues first, then performance, then style/nitpicks).

For each actionable comment:

1. Read the relevant file to understand full context.
2. Apply the fix using the Edit tool.
3. Verify the edit looks correct (re-read the affected lines).
4. Note what was changed and why.

**What counts as actionable:**

- Bug fixes
- Security improvements
- Performance improvements
- Code style or clarity improvements with a clear suggested change

**What to skip:**

- Comments that are purely informational with no suggested change
- Nitpicks marked as optional where the existing code is already reasonable
- Suggestions that contradict the evident intent of the code (flag these instead)

### 5. Report Results

After applying all fixes, present a summary:

```markdown
# CodeRabbit Review — Applied Fixes

## Summary

- **Issues found**: N
- **Fixes applied**: M
- **Skipped / flagged**: K

---

## Applied Fixes

### `path/to/file.ext`

- **[Bug]** Description of issue → what was changed
- **[Security]** Description of issue → what was changed

### `path/to/other.ext`

- **[Style]** Description of issue → what was changed

---

## Skipped / Needs Manual Attention

- `path/to/file.ext` — Description of issue and why it was skipped or needs human judgement

---

**Branch**: [current-branch]
**Base**: main
```

## Important Guidelines

1. **Fix, don't just report** — the goal is a clean branch, not a list of problems.
2. **Preserve intent** — only change what CodeRabbit flagged; don't refactor surrounding code.
3. **Read before editing** — always read the full context of a file before making a change.
4. **One fix per edit** — make targeted edits; avoid large rewrites unless the suggestion requires it.
5. **Flag conflicts** — if a suggestion contradicts the evident design, skip it and note it in the report.

---

**Begin now. Run CodeRabbit, parse the output, apply fixes, then present the summary.**
