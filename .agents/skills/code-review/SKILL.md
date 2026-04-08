---
name: code-review
description: Language-agnostic code review comparing current branch to main. Checks for breaking changes, code quality, test coverage, and framework-specific patterns. Outputs AI agent prompts by default; use `--full` for a complete actionable report with per-file grouping, two severity tiers, and inline diffs. Use `--lang <ext>` to filter to a specific file extension.
argument-hint: "[--lang <ext>] [--full]"
disable-model-invocation: false
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git branch --show-current)
  - Bash(git rev-parse --git-dir)
  - Bash(git diff --name-only *)
  - Bash(git diff origin/main...HEAD *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(test -f *)
model: sonnet
---

# Code Review

Perform a comprehensive code review of changes in the current branch compared to the main branch.

## Your Task

You are a senior developer conducting a thorough code review. Your goal is to identify breaking changes, code
quality issues, missing tests, and framework-specific problems. Be strict about breaking changes but constructive
with recommendations.

## Review Process

### 0. Detect Output Mode

Before doing anything else, check `$ARGUMENTS` for the `--full` flag.

- If `--full` is present: set **MODE=full**
- Otherwise (default): set **MODE=agents**

This controls Step 8 (report generation) entirely. All analysis steps (1–7) run the same regardless of mode.

---

### 1. Verify Git Repository

Verify you're in a git repository and not on the main branch:

```bash
git rev-parse --git-dir
git branch --show-current
```

If not in a git repo or on main branch, inform the user and exit gracefully.

---

### 2. Identify Changed Files

Check `$ARGUMENTS` for a `--lang <ext>` filter (e.g. `--lang php`, `--lang ts`, `--lang py`).

**With `--lang <ext>`:**

```bash
git diff --name-only origin/main...HEAD | grep '\.<ext>$'
```

**Without `--lang`** (review all changed files):

```bash
git diff --name-only origin/main...HEAD
```

If no files match, inform the user and exit gracefully.

---

### 3. Detect Available Tools

> **Extension point** — language-specific skills override this step with concrete tool paths.

For each language detected among the changed files, check for common linters, static analyzers, and test
runners using `test -f <path>`. Record any found tools for use in Steps 6 and 7.

If no tools are found, proceed with manual review only.

---

### 4. Ask Permission for Tool Execution

If tools are found, ask the user for permission before running them:

- For each static analyzer found: "Found `<tool>`. Run static analysis on changed files?"
- For each test runner found: "Found `<tool>`. Run tests for changed files?"

Use the AskUserQuestion tool. If denied, continue with manual review only.

---

### 5. Analyze Each Changed File

For each changed file, collect findings using the structure below. This powers both the full report and the
AI agent prompts.

#### Get File Diff

```bash
git diff origin/main...HEAD -- path/to/file
```

#### Severity tiers

Classify every finding into exactly one tier:

**Actionable** — blocking; must be fixed before merge:

- Breaking changes: method/function signature changes, removed public API, interface contract changes,
  constructor signature changes, added abstract/required methods, visibility changes (public → private)
- Security issues: injection vulnerabilities (SQL, command, template, etc.), XSS (unescaped output),
  hardcoded credentials or secrets, missing authentication/authorization checks
- Framework BC breaks: data-loss migrations, removed routes or API endpoints, changed event/job payload
  structure, removed config keys

**Nitpick** — non-blocking; should be improved:

- Missing type annotations or return types
- Redundant comments that duplicate what types already declare
- Missing comments that provide real value (complex logic, "why" explanations, generic type annotations)
- Outdated or conflicting comments/docblocks
- Framework-specific pattern issues (see Step 5D)
- Missing test coverage for new or modified files
- Cognitive complexity (functions > 50 lines, nesting > 4 levels) — only check manually if a static
  analyzer was not run or did not flag it
- Duplicated code (always check regardless of static analysis)
- Silent failures (empty catch/rescue blocks), uncaught exceptions, missing input validation

#### Finding object structure

For each issue found, record:

```
file:              "path/to/File"
tier:              "actionable" | "nitpick"
lines:             "39-55"          // single line or range
description:       "Clear prose explanation of the issue and its impact."
proposed_refactor: |                // diff string, or null if no concrete fix is possible
  -    old code
  +    new code
ai_prompt: |
  In `@path/to/File` around lines 39-55, [exact description of what to change and where to look,
  written so a fresh agent with no prior context can act on it]. Verify each finding against the
  current code and only fix it if needed.
```

Rules for `ai_prompt`:

- Always prefix the file path with `@` (e.g. `@src/services/UserService.ts`)
- Always include the line range
- Must be entirely self-contained — no pronouns that assume prior context
- Describe exactly what to change, what to look for, and any related symbols to touch

#### A. Breaking Changes Detection

**Function/Method Signature Changes:**

- Parameter additions without default values
- Parameter type changes
- Return type changes
- Parameter removals
- Visibility changes (public → protected/private)
- Method/function removals (public API only)

**Class/Interface/Contract Changes:**

- Removed public methods, functions, or properties
- Changed interface or type contracts
- New abstract/required methods (forces implementors to update)
- Added `final` or equivalent keyword (prevents extension)
- Changed constructor/initializer signatures

**Property/Field Changes:**

- Removed public properties or exported fields
- Changed property visibility
- Changed property types

#### B. Framework-Specific Breaking Changes

> **Extension point** — language-specific skills override this section with concrete rules.

Detect the project's framework from config files (e.g. `composer.json`, `package.json`, `pyproject.toml`,
`Gemfile`, `go.mod`). Then check for common BC patterns relevant to that framework:

- **Database**: column/schema removals or destructive renames, irreversible migrations
- **Routing/API**: removed routes or named route helpers, changed route parameters, removed API endpoints
- **Messaging/Events**: changed event or job payload structure that breaks queued consumers
- **Configuration**: removed config keys or changed value types that callers depend on

Flag any of the above as **Actionable**.

#### C. Code Quality Issues

**Type Safety:**

- Missing type annotations on parameters
- Missing return types
- Use of `any`/`mixed`/untyped when a specific type is possible
- Type declarations conflicting with actual implementation

**Documentation:**

- **Value-adding comments**: Missing explanations for complex or non-obvious logic. These comments explain
  'why', not 'what'.
- **Redundant comments**: Flag comments that duplicate information already expressed by types or names
- **Outdated documentation**: Comments or docblocks that conflict with actual implementation

**Error Handling:**

- Uncaught exceptions, missing input validation, silent failures (empty catch/rescue blocks)

**Code/Cognitive Complexity:**

- Rely on static analysis for complexity warnings when available and executed
- If not available or not run, check manually: functions > 50 lines, nesting > 4 levels
- Always check for duplicated code regardless of static analysis

**Security:**

- Injection vulnerabilities (SQL, command, template, etc.)
- Unescaped output (XSS)
- Hardcoded credentials or secrets
- Missing authentication/authorization checks

#### D. Framework Pattern Review

> **Extension point** — language-specific skills override this section with concrete rules.

Check for common anti-patterns relevant to the detected framework/stack:

- Patterns that cause performance problems (e.g. N+1 queries, blocking calls in async contexts)
- Patterns that risk data integrity (e.g. missing transactions, unsafe mass assignment)
- Patterns that complicate testing or maintenance (e.g. hidden side effects in constructors, global state)
- Patterns discouraged by the framework's own documentation

Flag as **Nitpick** unless the pattern causes a direct correctness or security issue, in which case flag
as **Actionable**.

#### E. Test Coverage Analysis

> **Extension point** — language-specific skills can override test file location conventions.

For each changed file, check if a corresponding test file exists. Common conventions:

- Mirror source path under `tests/`, `__tests__/`, `spec/`, or `test/`
- Same filename with a `Test`, `_test`, `.test`, or `.spec` suffix
- Module-local test directories (e.g. `src/module/tests/`)

**Files that typically don't need tests** (skip coverage findings for):

- Build/config files (`*.config.*`, `Makefile`, `Dockerfile`, etc.)
- Database migration files
- Route/URL definition files
- Static asset or language/locale files

**Flag as Nitpick:**

- New files without any corresponding test file
- Modified files where the test file wasn't also updated (check git diff for the test file)

---

### 6. Run Static Analysis (If Approved)

> **Extension point** — language-specific skills override this with concrete commands.

If the user approved static analysis execution, run the analyzer on all changed files. Parse the output and
classify each finding as Actionable or Nitpick, then add to your findings collection. Clearly note whether
an issue came from a changed file or the broader codebase.

If no static analyzer is installed, skip this step.

---

### 7. Run Tests (If Approved)

> **Extension point** — language-specific skills override this with concrete commands.

If the user approved test execution, run only the test files corresponding to the changed source files —
NOT the entire test suite.

If no test files exist for the changed code, skip execution and add a Nitpick finding per file.

---

### 8. Generate Report

By now you have a complete collection of finding objects from Step 5 (and optionally Steps 6–7).
Branch on MODE:

---

#### MODE=agents (default)

Output only:

```markdown
# AI Agent Prompts: Code Review — [branch-name]

Verify each finding against the current code and only fix it if needed.

## Actionable

In `@path/to/File` around lines 39-55: [self-contained fix instruction]

In `@path/to/File2` around lines 12-18: [self-contained fix instruction]

## Nitpick

In `@path/to/File` around lines 73-75: [self-contained fix instruction]

In `@path/to/File3` around lines 101-110: [self-contained fix instruction]
```

Rules for agents mode:

- No diffs, no prose explanations, no section headers beyond the two severity sections
- Every prompt is entirely self-contained
- Actionable prompts first, then Nitpick
- Within each section, group by file (all prompts for the same file together)
- If no findings: output the header and "No findings." under each section

---

#### MODE=full (`--full` flag)

Present the following markdown report:

```markdown
# Code Review: [branch-name]

## Review summary

- **Files selected**: X
- **Actionable comments**: Y
- **Nitpick comments**: Z

---

## 🚨 Actionable comments (Y)

### `path/to/File` (count of actionable findings in this file)

**39-55**: [Description of the issue and its impact.]

♻️ Proposed refactor

```diff
- old code
+ new code
```

🤖 Prompt for AI Agents
Verify each finding against the current code and only fix it if needed.

In `@path/to/File` around lines 39-55, [self-contained instruction].

---

## 🧹 Nitpick comments (Z)

### `path/to/File` (count of nitpick findings in this file)

**73-75**: [Description of the issue.]

♻️ Proposed refactor

```diff
- old code
+ new code
```

🤖 Prompt for AI Agents
In `@path/to/File` around lines 73-75, [self-contained instruction].

---

## 🤖 Prompt for all review comments with AI agents

Verify each finding against the current code and only fix it if needed.

### Actionable

In `@path/to/File` around lines 39-55: [same prompt as inline]

### Nitpick

In `@path/to/File` around lines 73-75: [same prompt as inline]

---

## ℹ️ Review info

**Files selected for processing (X)**

- `path/to/File1`
- `path/to/File2`

**Files with no reviewable changes**

- [files where diff was empty]

**Files ignored / excluded from test coverage**

- [list]

**Tools used**: [list tools actually run]
**Review completed**: [current date]
**Branch**: [branch-name] → main

---

After presenting, ask: "Would you like me to save this report to `code-review-report.md`?"

---

## Important Guidelines

1. **Collect findings first, report last** — do all analysis in Steps 5–7, then generate the report in Step 8
2. **Per-file grouping** — within each severity tier, group findings by file
3. **Be strict about Actionable** — flag ALL potential breaking changes and security issues
4. **Be constructive with Nitpick** — provide actionable diffs where possible
5. **AI prompts must be self-contained** — a fresh agent with no context must be able to act on them
6. **Include line numbers** — always reference exact line ranges
7. **Graceful degradation** — if tools aren't installed, perform thorough manual review
8. **Respect user choice** — if user denies tool execution, don't run it
9. **Default is agents mode** — only produce the full report when `--full` is passed

## Edge Cases to Handle

- **Already on main branch**: Warn user and ask which branch to compare
- **No files match the filter**: Inform user gracefully
- **New files only**: Add Nitpick for missing tests; skip BC break analysis (no prior API to break)
- **Deleted files only**: Classify removed public APIs as Actionable
- **No tools installed**: Perform thorough manual review only

---

**Begin your review now. Follow the steps above methodically.**
