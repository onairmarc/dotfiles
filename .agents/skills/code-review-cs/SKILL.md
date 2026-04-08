---
name: cs-code-review
description: C#/.NET code review extending the base code-review skill. Checks for breaking changes, code quality, test coverage, and ASP.NET Core / Entity Framework patterns. Outputs AI agent prompts by default; use `--full` for a complete actionable report with per-file grouping, two severity tiers, and inline diffs.
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
  - Bash(dotnet build *)
  - Bash(dotnet test *)
model: sonnet
---

# C# Code Review (extends code-review)

This skill extends the base `code-review` skill with C#/.NET-specific rules.

**Before doing anything else**, read the base skill:

```
~/.claude/skills/code-review/SKILL.md
```

Follow every step defined there, applying the overrides below in the matching steps. Where a section is
marked **Extension point** in the base skill, replace it entirely with the C#-specific version below.

---

## Override: Step 2 — File Filter

Filter for `.cs` files only:

```bash
git diff --name-only origin/main...HEAD | grep '\.cs$'
```

If no C# files changed, inform the user and exit gracefully.

---

## Override: Step 3 — Detect Available Tools

Check for installed .NET development tools:

```bash
test -f .config/dotnet-tools.json && echo "tools-manifest:.config/dotnet-tools.json"
```

Then search for test projects:

```bash
git diff --name-only origin/main...HEAD | grep '\.cs$'
```

Use Glob to find test projects in the repository:

```
**/*.Tests.csproj
**/*.Test.csproj
**/*Tests.csproj
**/*Test.csproj
```

If any test projects are found, record `dotnet test` as available. Always record `dotnet build` as
available (assume .NET SDK is installed).

---

## Override: Step 4 — Permission Prompts

If tools are found, ask the user:

- Always: "`dotnet build` is available. Run build with analyzer warnings on changed projects?"
- If test projects found: "`dotnet test` is available. Run tests for changed files?"

Use the AskUserQuestion tool. If denied, continue with manual review only.

---

## Override: Step 5B — Framework-Specific Breaking Changes

Detect the project type from config files (check for `*.csproj` referencing `Microsoft.AspNetCore`,
`Microsoft.EntityFrameworkCore`, etc.).

**Entity Framework Core Migrations:**

- Column removals or renames (data loss risk)
- Adding non-nullable columns without a default value on existing tables
- Changing column types without a safe migration plan
- Missing `Down()` method implementation
- Destructive operations in `Up()` alongside constructive ones (they should be separate)

**ASP.NET Core Routes / API Changes:**

- Removed `[Route]`, `[HttpGet]`, `[HttpPost]` (etc.) endpoints (BC break for API consumers)
- Changed route templates or route parameter names (e.g., `{id}` → `{guid}`)
- Removed or renamed controller actions that are part of the public API
- Changed middleware registration order or removed middleware

**Dependency Injection / Service Registration:**

- Removed or renamed service interfaces that other components depend on
- Changed constructor parameters of registered services (breaks DI resolution)
- Switching a `Singleton` to `Scoped`/`Transient` (or vice versa) — may break consumers

**Events / Background Jobs / Queues:**

- Removed properties from message/event/job classes (BC break for in-flight messages)
- Changed serialized payload structure (breaks deserialization of queued items)

**Configuration:**

- Removed config keys read via `IConfiguration` or `IOptions<T>`
- Changed config value types expected by bound `IOptions<T>` classes

---

## Override: Step 5D — Framework Pattern Review

**Entity Framework Core:**

- N+1 query risks — missing `.Include()` / eager loading on navigation properties
- Missing `.AsNoTracking()` on read-only queries (performance)
- Missing database indexes for foreign keys or frequently filtered columns
- Using foreign key constraints in migrations — the database should not enforce relational
  integrity; the application code should. Flag any `AddForeignKey` calls.
- Calling `.Result` or `.Wait()` on async EF queries (deadlock risk)
- Querying inside a loop instead of batching

**ASP.NET Core:**

- `async void` controller actions or middleware (unhandled exceptions crash the process)
- Blocking async code with `.Result`, `.Wait()`, or `GetAwaiter().GetResult()` on the
  request path (thread-pool starvation)
- Returning `IEnumerable<T>` from API actions instead of `IActionResult` / `ActionResult<T>`
  (loses content negotiation and status code control)
- Missing `[Authorize]` or authorization checks on endpoints that handle sensitive data
- Storing sensitive data in `HttpContext.Items` without clearing it

**Dependency Injection:**

- Captive dependency: a `Singleton` service injecting a `Scoped` or `Transient` service
  (Scoped services are disposed after the request; the Singleton will hold a stale reference)
- Resolving services directly from `IServiceProvider` in application code instead of
  constructor injection (service locator anti-pattern)
- Registering concrete types instead of interfaces (breaks testability)
- Heavy work in service constructors (delays startup, complicates testing)

**Async / Threading:**

- `async void` methods outside event handlers (exceptions are unobservable)
- Missing `CancellationToken` propagation through the call chain
- `Task.Run` on the request path wrapping synchronous blocking code instead of making it
  truly async
- `ConfigureAwait(false)` missing in library code (can cause deadlocks in certain sync contexts)

**Nullable Reference Types:**

- Null-forgiving operator (`!`) used to suppress warnings without a comment explaining why
  it is safe
- Nullable `string?` parameters without null guards at public API boundaries
- `#nullable disable` pragmas introduced without justification

---

## Override: Step 5E — Test Coverage Analysis

For each changed C# file, check if a corresponding test file exists.

**Test File Locations to Check:**

For `src/MyProject/Services/UserService.cs`, look for:

- `tests/MyProject.Tests/Services/UserServiceTests.cs`
- `tests/MyProject.Tests/Services/UserServiceTest.cs`
- `MyProject.Tests/Services/UserServiceTests.cs`
- `MyProject.Tests/Services/UserServiceTest.cs`

For `src/MyProject/Controllers/UserController.cs`, look for:

- `tests/MyProject.Tests/Controllers/UserControllerTests.cs`
- `tests/MyProject.Tests/Controllers/UserControllerTest.cs`

**Files That Don't Need Tests (exclude from test coverage findings):**

- EF Core migration files (`Migrations/*.cs`, `*_Migration.cs`, files containing `migrationBuilder`)
- Program entry points (`Program.cs`)
- Startup / host configuration files (`Startup.cs`)
- Auto-generated files (`*.g.cs`, `*.Designer.cs`, `*.generated.cs`)
- Interface definitions that contain no logic

**Flag as Nitpick:**

- New files without any corresponding test file (except excluded types above)
- Modified files where the test file wasn't updated (check git diff for the test file)

---

## Override: Step 6 — Run Static Analysis (If Approved)

If user approved `dotnet build` execution:

**A. Identify the solution or project file:**

```bash
test -f *.sln && echo "solution found"
```

Use Glob to find the nearest `.sln` or `.csproj` if not obvious from the changed file paths.

**B. Run build with warnings as errors suppressed (to see all warnings):**

```bash
dotnet build path/to/Project.csproj --no-incremental -warnaserror:false 2>&1
```

Or for a solution:

```bash
dotnet build MyApp.sln --no-incremental -warnaserror:false 2>&1
```

Parse the output. Classify each compiler warning / Roslyn analyzer finding as Actionable or
Nitpick and add it to your findings collection. Clearly note whether an issue came from a changed
file or the broader codebase.

- **CS8600–CS8629** (nullable warnings): Nitpick unless it masks a real null-dereference risk
- **CS0618** (obsolete API): Nitpick
- **CA1xxx / SA1xxx** (code analysis / style): Nitpick
- **Build errors (CSxxxx errors)**: Actionable

---

## Override: Step 7 — Run Tests (If Approved)

If user approved test execution, run only the test project(s) that cover the changed C# files —
NOT the entire solution.

**Identify relevant test project(s)** by matching changed source paths to test project folders
found in Step 3.

```bash
dotnet test tests/MyProject.Tests/MyProject.Tests.csproj --no-build 2>&1
```

If `--no-build` fails (project not yet built), drop that flag:

```bash
dotnet test tests/MyProject.Tests/MyProject.Tests.csproj 2>&1
```

If no test files exist for the changed code, skip execution and add a Nitpick finding per file.

---

## Additional Edge Cases (C#-specific)

- **Auto-generated files**: Skip `.g.cs`, `*.Designer.cs`, and `*.generated.cs` files entirely —
  do not report findings on machine-generated code
- **Partial classes**: When a `partial class` is split across multiple files, read all parts
  before drawing conclusions about completeness
- **No C# files changed**: Inform user gracefully and exit

---

**Begin your review now. Follow the base skill steps with the overrides above applied.**
