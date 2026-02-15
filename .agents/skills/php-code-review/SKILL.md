---
name: php-code-review
description: Comprehensive PHP code review comparing current branch to main. Checks for breaking changes, code quality, test coverage, and Laravel patterns. Use when reviewing PHP code changes before merge or when preparing for release.
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

### 1. Verify Git Repository

First, verify you're in a git repository and not on the main branch:

```bash
# Check if in git repo
git rev-parse --git-dir

# Get current branch name
git branch --show-current
```

If not in a git repo or on main branch, inform the user and exit gracefully.

### 2. Identify Changed PHP Files

Get all PHP files that have changed compared to main:

```bash
git diff --name-only origin/main...HEAD | grep '\.php$'
```

If no PHP files changed, inform the user and exit gracefully.

### 3. Detect Available Tools

Check for installed development tools in the repository:

```bash
# Check for PHPStan (standard location)
test -f vendor/bin/phpstan && echo "phpstan:vendor/bin/phpstan"

# Check for PHPStan (monorepo location)
test -f application/vendor/bin/phpstan && echo "phpstan:application/vendor/bin/phpstan"

# Check for Pest
test -f vendor/bin/pest && echo "pest:vendor/bin/pest"
test -f application/vendor/bin/pest && echo "pest:application/vendor/bin/pest"

# Check for PHPUnit
test -f vendor/bin/phpunit && echo "phpunit:vendor/bin/phpunit"
test -f application/vendor/bin/phpunit && echo "phpunit:application/vendor/bin/phpunit"
```

Store which tools are available for later use.

**IMPORTANT**: If both Pest and PHPUnit are present, prefer Pest over PHPUnit for test execution.

### 4. Ask Permission for Tool Execution

If tools are found, ask the user for permission before running them:

- If PHPStan found: "PHPStan is installed. Run static analysis on changed files?"
- If Pest/PHPUnit found: "Run test suite to verify coverage?"

Use the AskUserQuestion tool to get permission. If denied, continue with manual review only.

### 5. Analyze Each Changed File

For each PHP file that changed, perform the following analysis:

#### Get File Diff

```bash
git diff origin/main...HEAD -- path/to/file.php
```

#### A. Breaking Changes Detection (CRITICAL)

Examine the diff for these breaking changes:

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
- Removed fields that listeners/consumers depend on

**Configuration:**

- Removed config keys (breaks `config()` calls)
- Changed config value types

#### C. Code Quality Issues

Look for these code quality problems:

**Type Safety:**

- Missing type hints on parameters
- Missing return types
- Use of `mixed` type when specific type is possible
- Docblocks conflicting with actual types

**Documentation:**

- **Laravel Models**: Missing property docblocks (required for IDE auto-completion). Every property the model exposes
  should be documented in the class-level docblock with `@property` or `@property-read` tags as appropriate.
- **Docblocks with Value**: Missing PHPDoc blocks that provide actual value:
    - Explaining complex logic or "why" something is done (not just "what")
    - Defining generic types (e.g., `@return Collection<int, User>`)
    - Documenting magic methods or dynamic properties
- **Redundant Docblocks**: Flag docblocks that duplicate type information already declared in PHP code. If the method
  signature has parameter types and return types, docblocks are redundant and should be removed.
- **Outdated Documentation**: Docblocks that conflict with actual implementation

**Error Handling:**

- Uncaught exceptions
- Missing validation
- Silent failures (empty catch blocks)

**Code/Cognitive Complexity:**

- Rely on the PHPStan for cognitive complexity warnings.
    - If PHPStan is available, was executed, and does not flag cognitive complexity warnings, then skip the cognitive
      complexity analysis.
- If PHPStan is not available, or was not executed, or does not flag cognative complexity warnings, perform the
  following analysis:
    - Methods longer than 50 lines
    - Deeply nested code (>4 levels)
    - High cyclomatic complexity
- Always perform the following analysis regardless of PHPStan presence, use, or output:
    - Duplicated code

**Security:**

- Potential SQL injection (raw queries without bindings)
- XSS vulnerabilities (unescaped output)
- Hardcoded credentials or secrets
- Missing CSRF protection

#### D. Laravel Pattern Review

For Laravel projects, check these patterns:

**Database Migrations:**

- Missing indexes
- The use of foreign keys. The database should not be in charge of constraints. The application code should be.
- Missing `down()` method (unless the `up()` method is destructive)
- `up()` methods should either create or change tables or destroy/drop tables, never both.
- Using `dropColumn()` without checking existence
- Schema changes without considering existing data

**Service Providers:**

- Heavy operations in `boot()` method (performance impact)
- Singleton bindings. Always prefer scoped or transient.
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

#### E. Test Coverage Analysis

For each changed file, check if a corresponding test file exists:

**Test File Locations to Check:**
For `app/Services/UserService.php`, look for:

- `tests/Unit/Services/UserServiceTest.php`
- `tests/Feature/Services/UserServiceTest.php`
- `tests/Services/UserServiceTest.php`

- For `app_modules/{Module}/src/Services/UserService.php`, look for:

- `app_modules/{Module}/tests/Unit/Services/UserServiceTest.php`
- `app_modules/{Module}/tests/Feature/Services/UserServiceTest.php`
- `app_modules/{Module}/tests/Services/UserServiceTest.php`

**Files That Don't Need Tests:**

- Config files (`config/*.php`)
- Database migrations (`database/migrations/*.php`)
- Routes files (`routes/*.php`)
- Language files (`lang/*.php`, `resources/lang/*.php`)

**Flag as Missing Tests:**

- New files without any test file
- Modified files where test file wasn't updated (check git diff for test file)

### 6. Run Static Analysis (If Approved)

If user approved PHPStan execution:

**A. Run PHPStan on all changed files:**

```bash
# Run PHPStan on all changed files together
vendor/bin/phpstan analyze app/Services/UserService.php app/Models/User.php --error-format=json
```

Parse the JSON output and include findings specific to the changed files in the report.

**B. Run PHPStan on the entire repository:**

```bash
# Run PHPStan on the whole repo to catch any other issues
vendor/bin/phpstan analyze --error-format=json
```

This catches issues that might not be in the changed files directly but could be affected by the changes (e.g., usages
of changed methods, interfaces, etc.).

Parse the JSON output from both runs and include all findings in the report. Clearly distinguish between issues in
changed files vs. issues found in the broader codebase.

### 7. Run Tests (If Approved)

If user approved test execution:

**IMPORTANT**: Only run tests for the changed files, NOT the entire test suite. Large test suites can take a long time
and bog down the review process.

**A. Identify test files for changed PHP files:**

For each changed file (e.g., `app/Services/UserService.php`), find its corresponding test file:

- `tests/Unit/Services/UserServiceTest.php`
- `tests/Feature/Services/UserServiceTest.php`
- `tests/Services/UserServiceTest.php`

For each changed file (e.g., `app_modules/{Module}/Services/UserService.php`), find its corresponding test file:

- `app_modules/{Module}/tests/Unit/Services/UserServiceTest.php`
- `app_modules/{Module}/tests/Feature/Services/UserServiceTest.php`
- `app_modules/{Module}/tests/Services/UserServiceTest.php`

**B. Run only the identified test files:**

**IMPORTANT**: If both Pest and PHPUnit are available, use Pest (NOT PHPUnit).

```bash
# Run Pest on specific test files only (preferred if available)
vendor/bin/pest tests/Unit/Services/UserServiceTest.php tests/Feature/ProductControllerTest.php

# Or run PHPUnit on specific test files only (only if Pest is not available)
vendor/bin/phpunit tests/Unit/Services/UserServiceTest.php tests/Feature/ProductControllerTest.php
```

**C. If no test files found for changed code:**

Skip test execution and flag in the report that the changed files have no tests.

Include test results for the specific test files that were run. Do NOT run the full test suite.

### 8. Generate Markdown Report

Create a comprehensive markdown report with the following structure:

```markdown
# PHP Code Review: [Branch Name]

## Summary

- **Files Changed**: X PHP files
- **Breaking Changes**: Y issues found
- **Code Quality**: Z issues found
- **Test Coverage**: N files without tests
- **Laravel Patterns**: M issues found

---

## 🚨 Breaking Changes [CRITICAL]

[List all breaking changes found, organized by category]

### Method Signature Changes

- `ClassName::methodName()` - Description of BC break
    - File: `path/to/file.php:42`
    - Impact: What needs to be updated

### Removed Methods/Properties

[List removed public APIs]

### Laravel BC Breaks

[List Laravel-specific BC breaks]

---

## ⚠️ Code Quality Issues

### PHPStan Analysis

[If PHPStan was run, include results]

### Manual Review Findings

- Missing return type: `ClassName::method()`
- Security risk: SQL injection in `ClassName::query()`
- Complexity: `ClassName::process()` has 8 levels of nesting

---

## 🧪 Test Coverage

### Files Missing Tests

- ❌ `app/Services/OrderService.php` - NEW file, no tests found
- ❌ `app/Http/Controllers/ProductController.php` - MODIFIED, no test updates

### Files With Tests

- ✅ `app/Services/UserService.php` - Test exists: `tests/Unit/Services/UserServiceTest.php`

[Include test suite results if run]

---

## 🎯 Laravel Pattern Review

### Database Migrations

[List migration issues]

### Service Providers

[List provider issues]

### Routes/API Changes

[List route changes and BC implications]

### Queue Jobs/Events

[List job/event issues]

---

## 📋 Recommendations

### 1. Immediate Action Required

[Critical issues that must be fixed before merge]

### 2. Before Merge

[Important issues to address]

### 3. Nice to Have

[Suggestions for improvement]

---

**Review completed on**: [Current Date]
**Branch**: [branch-name]
**Base**: main
**Tools used**: [List of tools actually used]
```

## Important Guidelines

1. **Be Thorough**: Review every changed line for potential issues
2. **Be Strict About BC Breaks**: Flag ALL potential breaking changes
3. **Be Constructive**: Provide clear explanations and actionable fixes
4. **Prioritize Issues**: Use 🚨 for critical, ⚠️ for warnings, ✅ for good
5. **Include Context**: Always include file paths and line numbers
6. **Consider Impact**: Explain WHO is affected by each breaking change
7. **Graceful Degradation**: If tools aren't installed, do manual review
8. **Respect User Choice**: If user denies tool execution, don't run it

## Edge Cases to Handle

- **Already on main branch**: Warn user and ask which branch to compare
- **No PHP files changed**: Inform user gracefully
- **New files only**: Flag for test coverage, skip BC break analysis
- **Deleted files only**: Note the removals as potential BC breaks
- **No tools installed**: Perform thorough manual review
- **Monorepo structure**: Check both `vendor/bin/` and `application/vendor/bin/`

## Output Format

Present the complete markdown report to the user. After presenting, ask:

"Would you like me to save this report to a file for use in a pull request description?"

If yes, save to `code-review-report.md` in the repository root.

---

**Begin your review now. Follow the steps above methodically.**
