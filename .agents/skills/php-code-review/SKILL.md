---
name: php-code-review
description: Comprehensive PHP code review comparing current branch to main. Checks for breaking changes, code quality, test coverage, and Laravel patterns. Outputs in CodeRabbit style with per-file grouping, two severity tiers, inline diffs, and AI agent prompts. Use `--agents` flag for AI-prompts-only output.
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
  - Bash(vendor/bin/phpstan *)
  - Bash(application/vendor/bin/phpstan *)
  - Bash(vendor/bin/pest *)
  - Bash(application/vendor/bin/pest *)
  - Bash(vendor/bin/phpunit *)
  - Bash(application/vendor/bin/phpunit *)
model: sonnet
---

# PHP Code Review

Perform a comprehensive code review of PHP changes in the current branch compared to the main branch.

## Your Task

You are a senior PHP developer conducting a thorough code review. Your goal is to identify breaking changes, code
quality issues, missing tests, and Laravel-specific problems. Be strict about breaking changes but constructive with
recommendations.

## Review Process

### 0. Detect Output Mode

Before doing anything else, check whether the skill was invoked with the `--agents` flag
(e.g. `/php-code-review --agents`).

- If `--agents` is present: set **MODE=agents**
- Otherwise: set **MODE=full**

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

### 2. Identify Changed PHP Files

Get all PHP files that have changed compared to main:

```bash
git diff --name-only origin/main...HEAD | grep '\.php$'
```

If no PHP files changed, inform the user and exit gracefully.

---

### 3. Detect Available Tools

Check for installed development tools:

```bash
test -f vendor/bin/phpstan && echo "phpstan:vendor/bin/phpstan"
test -f application/vendor/bin/phpstan && echo "phpstan:application/vendor/bin/phpstan"
test -f vendor/bin/pest && echo "pest:vendor/bin/pest"
test -f application/vendor/bin/pest && echo "pest:application/vendor/bin/pest"
test -f vendor/bin/phpunit && echo "phpunit:vendor/bin/phpunit"
test -f application/vendor/bin/phpunit && echo "phpunit:application/vendor/bin/phpunit"
```

**IMPORTANT**: If both Pest and PHPUnit are present, prefer Pest over PHPUnit.

---

### 4. Ask Permission for Tool Execution

If tools are found, ask the user for permission before running them:

- If PHPStan found: "PHPStan is installed. Run static analysis on changed files?"
- If Pest/PHPUnit found: "Run test suite to verify coverage?"

Use the AskUserQuestion tool. If denied, continue with manual review only.

---

### 5. Analyze Each Changed File

For each PHP file that changed, collect findings using the structure below. This powers both the full report and the
AI agent prompts.

#### Get File Diff

```bash
git diff origin/main...HEAD -- path/to/file.php
```

#### Severity tiers

Classify every finding into exactly one tier:

**Actionable (🚨)** — blocking; must be fixed before merge:

- Breaking changes: method signature changes, removed public methods/properties, interface contract changes,
  constructor signature changes, added abstract methods, visibility changes (public → protected/private)
- Security issues: SQL injection (raw queries without bindings), XSS (unescaped output), hardcoded credentials or
  secrets, missing CSRF protection
- Laravel BC breaks: migration column removals or renames (data loss), added NOT NULL columns without defaults,
  removed route names, removed API endpoints, changed event/job payload structure, removed config keys

**Nitpick (🧹)** — non-blocking; should be improved:

- Missing type hints on parameters or missing return types
- Redundant docblocks (duplicate information already declared in PHP types)
- Missing docblocks that provide real value (Model `@property` tags, generic type annotations, "why" comments)
- Outdated or conflicting docblocks
- Laravel pattern issues: foreign keys in migrations, singleton bindings (prefer scoped/transient), N+1 query risks,
  missing `$fillable`/`$guarded`, heavy `boot()` methods, missing `down()` in migrations, mixing create and drop in
  the same `up()`
- Missing test coverage for new or modified files
- Cognitive complexity (methods > 50 lines, nesting > 4 levels, high cyclomatic complexity) — only check manually
  if PHPStan was not run or did not flag it
- Duplicated code (always check regardless of PHPStan)
- Silent failures (empty catch blocks), uncaught exceptions, missing validation
- Non-serializable job properties, missing retry/timeout/failure handling on queue jobs

#### Finding object structure

For each issue found, record:

```
file:              "path/to/File.php"
tier:              "actionable" | "nitpick"
lines:             "39-55"          // single line or range
description:       "Clear prose explanation of the issue and its impact."
proposed_refactor: |                // diff string, or null if no concrete fix is possible
  -    old code
  +    new code
ai_prompt: |
  In `@path/to/File.php` around lines 39-55, [exact description of what to change and where to look,
  written so a fresh agent with no prior context can act on it]. Verify each finding against the
  current code and only fix it if needed.
```

Rules for `ai_prompt`:

- Always prefix the file path with `@` (e.g. `@app/Services/UserService.php`)
- Always include the line range
- Must be entirely self-contained — no pronouns that assume prior context
- Describe exactly what to change, what to look for, and any related symbols to touch

#### A. Breaking Changes Detection

**Method Signature Changes:**

- Parameter additions without default values
- Parameter type changes (e.g., `string` → `int`)
- Return type changes (e.g., `void` → `bool`)
- Parameter removals
- Visibility changes (public → protected/private)
- Method removals (public methods only)

**Class/Interface Changes:**

- Removed public methods or properties
- Changed interface contracts
- New abstract methods (forces child classes to implement)
- Added `final` keyword (prevents extension)
- Changed constructor signatures

**Property Changes:**

- Removed public properties
- Changed property visibility
- Changed property types

#### B. Laravel-Specific Breaking Changes

If this is a Laravel project (check for `composer.json` with `laravel/framework`):

**Database Migrations:**

- Column removals or renames (data loss risk)
- Adding NOT NULL columns without defaults on existing tables
- Changing column types without migration plan
- Missing `down()` method implementation

**Routes/API Changes:**

- Removed route names (breaks `route()` helper calls)
- Changed route parameters (e.g., `{id}` → `{uuid}`)
- Removed API endpoints (BC break for API consumers)
- Changed middleware (may break authentication/authorization)

**Events/Jobs:**

- Removed properties from event/job classes (BC break for queued instances)
- Changed event/job payload structure

**Configuration:**

- Removed config keys (breaks `config()` calls)
- Changed config value types

#### C. Code Quality Issues

**Type Safety:**

- Missing type hints on parameters
- Missing return types
- Use of `mixed` type when specific type is possible
- Docblocks conflicting with actual types

**Documentation:**

- **Laravel Models**: Missing `@property`/`@property-read` docblocks (required for IDE auto-completion)
- **Docblocks with Value**: Missing PHPDoc blocks that explain complex logic, define generic types
  (e.g., `@return Collection<int, User>`), or document magic methods/dynamic properties
- **Redundant Docblocks**: Flag docblocks that duplicate type information already declared in PHP code
- **Outdated Documentation**: Docblocks that conflict with actual implementation

**Error Handling:**

- Uncaught exceptions, missing validation, silent failures (empty catch blocks)

**Code/Cognitive Complexity:**

- Rely on PHPStan for cognitive complexity warnings when available and executed
- If PHPStan is not available or not run, check manually: methods > 50 lines, nesting > 4 levels
- Always check for duplicated code regardless of PHPStan

**Security:**

- Potential SQL injection (raw queries without bindings)
- XSS vulnerabilities (unescaped output)
- Hardcoded credentials or secrets
- Missing CSRF protection

#### D. Laravel Pattern Review

**Database Migrations:**

- Missing indexes
- Use of foreign keys — the database should not be in charge of constraints; the application code should be
- Missing `down()` method (unless `up()` is destructive)
- `up()` methods should either create/change tables OR destroy/drop tables, never both
- Using `dropColumn()` without checking existence
- Schema changes without considering existing data

**Service Providers:**

- Heavy operations in `boot()` method (performance impact)
- Singleton bindings — always prefer scoped or transient
- Missing deferred provider optimisation
- Circular dependency risks

**Queue Jobs:**

- Non-serialisable properties (closures, resources, database connections)
- Missing `ShouldQueue` interface
- Missing retry/timeout configuration
- No failure handling

**Eloquent Models:**

- Missing `$fillable` or `$guarded` (mass assignment vulnerability)
- N+1 query risks (missing eager loading)
- Missing relationships that should exist

#### E. Test Coverage Analysis

For each changed file, check if a corresponding test file exists:

**Test File Locations to Check:**

For `app/Services/UserService.php`, look for:

- `tests/Unit/Services/UserServiceTest.php`
- `tests/Feature/Services/UserServiceTest.php`
- `tests/Services/UserServiceTest.php`

For `app_modules/{Module}/src/Services/UserService.php`, look for:

- `app_modules/{Module}/tests/Unit/Services/UserServiceTest.php`
- `app_modules/{Module}/tests/Feature/Services/UserServiceTest.php`
- `app_modules/{Module}/tests/Services/UserServiceTest.php`

**Files That Don't Need Tests (exclude from test coverage findings):**

- Config files (`config/*.php`)
- Database migrations (`database/migrations/*.php`)
- Routes files (`routes/*.php`)
- Language files (`lang/*.php`, `resources/lang/*.php`)

**Flag as Nitpick:**

- New files without any test file
- Modified files where the test file wasn't updated (check git diff for the test file)

---

### 6. Run Static Analysis (If Approved)

If user approved PHPStan execution:

**A. Run PHPStan on all changed files:**

```bash
vendor/bin/phpstan analyse app/Services/UserService.php app/Models/User.php --error-format=json
```

**B. Run PHPStan on the entire repository:**

```bash
vendor/bin/phpstan analyse --error-format=json
```

Parse the JSON output. Classify each PHPStan finding as Actionable or Nitpick and add it to your findings
collection. Clearly note whether an issue came from a changed file or the broader codebase.

---

### 7. Run Tests (If Approved)

If user approved test execution, run only the test files for the changed PHP files — NOT the entire test suite.

**IMPORTANT**: If both Pest and PHPUnit are available, use Pest.

```bash
# Preferred (Pest)
vendor/bin/pest tests/Unit/Services/UserServiceTest.php tests/Feature/ProductControllerTest.php

# Fallback (PHPUnit only if Pest unavailable)
vendor/bin/phpunit tests/Unit/Services/UserServiceTest.php tests/Feature/ProductControllerTest.php
```

If no test files exist for the changed code, skip execution and add a Nitpick finding per file.

---

### 8. Generate Report

By now you have a complete collection of finding objects from Step 5 (and optionally Steps 6–7).
Branch on MODE:

---

#### MODE=full (default)

Present the following markdown report:

```markdown
# PHP Code Review: [branch-name]

## Review summary

- **Files selected**: X
- **Actionable comments**: Y
- **Nitpick comments**: Z

---

## 🚨 Actionable comments (Y)

### `path/to/File.php` (count of actionable findings in this file)

**39-55**: [Description of the issue and its impact.]

♻️ Proposed refactor

```diff
- old code
+ new code
```

🤖 Prompt for AI Agents
In `@path/to/File.php` around lines 39-55, [self-contained instruction]. Verify each finding against
the current code and only fix it if needed.

---

## 🧹 Nitpick comments (Z)

### `path/to/File.php` (count of nitpick findings in this file)

**73-75**: [Description of the issue.]

♻️ Proposed refactor

```diff
- old code
+ new code
```

🤖 Prompt for AI Agents
Verify this finding against the current code and only fix it if needed:

In `@path/to/File.php` around lines 73-75, [self-contained instruction].

---

## 🤖 Prompt for all review comments with AI agents

Verify each finding against the current code and only fix it if needed.

### Actionable

In `@path/to/File.php` around lines 39-55: [same prompt as inline]

### Nitpick

In `@path/to/File.php` around lines 73-75: [same prompt as inline]

---

## ℹ️ Review info

**Files selected for processing (X)**

- `path/to/File1.php`
- `path/to/File2.php`

**Files with no reviewable changes**

- [files where diff was empty]

**Files ignored / excluded from test coverage**

- `database/migrations/*.php`
- `config/*.php`
- `routes/*.php`

**Tools used**: [list tools actually run]
**Review completed**: [current date]
**Branch**: [branch-name] → main

---

After presenting, ask: "Would you like me to save this report to `code-review-report.md`?"

#### MODE=agents (`--agents` flag)

Skip the full report entirely. Output only:

```markdown
# AI Agent Prompts: PHP Code Review — [branch-name]

Verify each finding against the current code and only fix it if needed.

## Actionable

In `@path/to/File.php` around lines 39-55: [self-contained fix instruction]

In `@path/to/File2.php` around lines 12-18: [self-contained fix instruction]

## Nitpick

In `@path/to/File.php` around lines 73-75: [self-contained fix instruction]

In `@path/to/File3.php` around lines 101-110: [self-contained fix instruction]
```

Rules for agents-only mode:

- No diffs, no prose explanations, no section headers beyond the two severity sections
- Every prompt is entirely self-contained
- Actionable prompts first, then Nitpick
- Within each section, group by file (all prompts for the same file together)

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
9. **`--agents` flag** — when set, output only the two-section AI prompt block; skip everything else

## Edge Cases to Handle

- **Already on main branch**: Warn user and ask which branch to compare
- **No PHP files changed**: Inform user gracefully
- **New files only**: Add Nitpick for missing tests; skip BC break analysis (no prior API to break)
- **Deleted files only**: Classify removed public APIs as Actionable
- **No tools installed**: Perform thorough manual review only
- **Monorepo structure**: Check both `vendor/bin/` and `application/vendor/bin/`
- **`--agents` flag with no findings**: Output the header and "No findings." under each section

---

**Begin your review now. Follow the steps above methodically.**
