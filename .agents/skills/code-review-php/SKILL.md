---
name: php-code-review
description: PHP/Laravel code review extending the base code-review skill. Checks for breaking changes, code quality, test coverage, and Laravel patterns. Outputs AI agent prompts by default; use `--full` for a complete actionable report with per-file grouping, two severity tiers, and inline diffs.
argument-hint: "[--full]"
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

# PHP Code Review (extends code-review)

This skill extends the base `code-review` skill with PHP/Laravel-specific rules.

**Before doing anything else**, read the base skill:

```
~/.claude/skills/code-review/SKILL.md
```

Follow every step defined there, applying the overrides below in the matching steps. Where a section is
marked **Extension point** in the base skill, replace it entirely with the PHP-specific version below.

---

## Override: Step 2 — File Filter

Filter for `.php` files only:

```bash
git diff --name-only origin/main...HEAD | grep '\.php$'
```

If no PHP files changed, inform the user and exit gracefully.

---

## Override: Step 3 — Detect Available Tools

Check for installed PHP development tools:

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

## Override: Step 4 — Permission Prompts

If tools are found, ask the user:

- If PHPStan found: "PHPStan is installed. Run static analysis on changed files?"
- If Pest/PHPUnit found: "Run test suite to verify coverage?"

Use the AskUserQuestion tool. If denied, continue with manual review only.

---

## Override: Step 5B — Framework-Specific Breaking Changes

If this is a Laravel project (check for `composer.json` with `laravel/framework`):

**Database Migrations:**

- Column removals or renames (data loss risk)
- Adding NOT NULL columns without defaults on existing tables
- Changing column types without a migration plan
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

---

## Override: Step 5D — Framework Pattern Review

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
- Missing deferred provider optimization
- Circular dependency risks

**Queue Jobs:**

- Non-serializable properties (closures, resources, database connections)
- Missing `ShouldQueue` interface
- Missing retry/timeout configuration
- No failure handling

**Eloquent Models:**

- Missing `$fillable` or `$guarded` (mass assignment vulnerability)
- N+1 query risks (missing eager loading)
- Missing relationships that should exist

---

## Override: Step 5E — Test Coverage Analysis

For each changed PHP file, check if a corresponding test file exists:

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

## Override: Step 6 — Run Static Analysis (If Approved)

If user approved PHPStan execution:

**A. Run PHPStan on all changed files:**

```bash
vendor/bin/phpstan analyse path/to/File1.php path/to/File2.php --error-format=json
```

**B. Run PHPStan on the entire repository:**

```bash
vendor/bin/phpstan analyse --error-format=json
```

Parse the JSON output. Classify each PHPStan finding as Actionable or Nitpick and add it to your findings
collection. Clearly note whether an issue came from a changed file or the broader codebase.

---

## Override: Step 7 — Run Tests (If Approved)

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

## Additional Edge Cases (PHP-specific)

- **Monorepo structure**: Check both `vendor/bin/` and `application/vendor/bin/` for all tools
- **No PHP files changed**: Inform user gracefully and exit

---

**Begin your review now. Follow the base skill steps with the overrides above applied.**
