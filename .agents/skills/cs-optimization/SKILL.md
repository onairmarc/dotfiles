---
name: cs-optimization
description: Audits a C# application or project path for performance issues (sync I/O on calling thread, LINQ inefficiency, excessive allocations, missing cancellation, improper async/await, memory leaks, inefficient collections, blocking thread pool), then delegates to the feature-planning skill to produce a self-contained, phased, agent-ready optimization plan. Does NOT execute optimizations. A single failing test in the plan's Phase 0 baseline gate is a hard stop.
argument-hint: "<project-path> [additional context]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(test -f *)
  - Bash(find * -name "*.cs" -type f)
  - Bash(cat *)
  - Skill(feature-planning)
  - AskUserQuestion
model: opus
---

# C# Optimization Skill

You are an expert C# performance engineer. Your job is to **audit** a project path, discover performance issues, and
then invoke the **feature-planning skill** to produce a self-contained, agent-ready optimization plan. You do not
execute any optimization code yourself.

**Input:** `$ARGUMENTS` — the project path to audit (e.g. `src/MyApp`, `src/MyApp.Core`, `src/Services`).

---

## Step 0 — Validate input

Parse `$ARGUMENTS`. Extract:

- `PROJECT_PATH` — first positional argument (required). If missing or the path does not exist, abort with:
  ```
  Error: PROJECT_PATH is required. Usage: /cs-optimization <path/to/project> [additional context]
  ```
- `EXTRA_CONTEXT` — everything after the first positional argument (optional). Free-form text the caller provides about
  known issues, architectural decisions, or constraints the automated audit may not discover (e.g. "the ConfigService is
  a singleton loaded on every request", "the report export is known to be slow for large datasets"). Preserve it
  verbatim.

Derive `PROJECT_NAME` from the last meaningful path segment (if last segment is `src`, use its parent).

---

## Step 1 — Detect project type

Read the `.csproj` file(s) in `PROJECT_PATH`. Classify the project:

| Signal                                                                              | Classification               |
|-------------------------------------------------------------------------------------|------------------------------|
| `<OutputType>Exe</OutputType>` or `<OutputType>WinExe</OutputType>`                 | **Console / Desktop App**    |
| `Microsoft.AspNetCore` or `Microsoft.NET.Sdk.Web` in SDK or `PackageReference`      | **ASP.NET Core Application** |
| `OutputType` is `Library` with no framework-specific hosting dependency             | **Class Library**            |
| Multiple `.csproj` files with shared `Domain`/`Application`/`Infrastructure` layers | **Multi-project Solution**   |

Record as `PROJECT_TYPE`. Scope rules per type:

- **Console / Desktop App** — out of scope: anything outside `PROJECT_PATH`, `obj/`, `bin/`
- **ASP.NET Core Application** — out of scope: anything outside `PROJECT_PATH`, `obj/`, `bin/`
- **Class Library** — out of scope: host application code, `bin/`, `obj/`
- **Multi-project Solution** — out of scope: projects not under `PROJECT_PATH`, `bin/`, `obj/`

Determine test root:

- Application: `tests/` at repo root, or `{PROJECT_PATH}.Tests/`
- Library: `{PROJECT_PATH}.Tests/` or nearest `Tests/` sibling
- Multi-project: project-local `Tests/` preferred, repo root `tests/` as fallback

Emit before continuing:

```
Project type: {PROJECT_TYPE}
Project:      {PROJECT_NAME} ({PROJECT_PATH})
Test root:    {TEST_ROOT}
```

If classification is ambiguous, state your best guess and the reason, then continue.

---

## Step 2 — Audit the project

Systematically search `PROJECT_PATH` for every problem category below. For each hit, **read the actual file to confirm
line numbers before recording**. Never approximate.

Record each finding as:

- **Category**
- **Class::Method()** (or class name)
- **File path** (exact, relative to repo root)
- **Line range**
- **One-sentence description of the specific problem**

### Async and threading patterns

| Problem                                         | How to detect                                                                                                                      |
|-------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| `Task.Result` or `.Wait()` deadlock risk        | Grep `\.Result\b` or `\.Wait\(\)` — flag all occurrences; deadlock risk in any synchronization context                             |
| `async void` outside event handlers             | `async void` method signatures where enclosing class does not inherit `Control`/`Page`/`Window` and method is not an event handler |
| `Task.Run` wrapping already-async code          | `Task.Run(() => SomeAsync())` — redundant wrapper that wastes a thread pool thread                                                 |
| `Thread.Sleep` instead of `Task.Delay`          | Grep `Thread\.Sleep\(` in any async or service context                                                                             |
| CPU-bound work on caller thread without offload | Loops processing large collections synchronously in a method that could be awaited by a UI or web request                          |
| Missing `CancellationToken` propagation         | `async` methods accepting `CancellationToken` but callers passing `CancellationToken.None` or omitting the parameter               |
| `CancellationTokenSource` not disposed          | `new CancellationTokenSource(...)` with no `using`, `Dispose()`, or `Cancel()` in a `finally`/destructor                           |
| `Parallel.ForEach` over async work              | `Parallel.ForEach` with `async` lambda — the async work runs fire-and-forget; use `Task.WhenAll` with `Select`                     |

### Memory allocation patterns

| Problem                                                | How to detect                                                                                                                         |
|--------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------|
| `string` concatenation in loop                         | `+=` on a `string` variable inside `for`/`foreach`/`while` — use `StringBuilder`                                                      |
| `string.Format` / interpolation for logging (hot path) | `$"..."` or `string.Format(...)` passed to a logger call that checks no enabled level — use structured logging with message templates |
| `ToList()` / `ToArray()` on intermediate LINQ          | `.ToList()` or `.ToArray()` on a LINQ chain that is immediately consumed by another LINQ operator — materialize once at the end       |
| `new List<T>()` without capacity hint for known size   | `new List<T>()` inside a loop or before an `AddRange` where the final count is known                                                  |
| Boxing value types via `object` parameter              | Value types passed to `object` parameters or non-generic collections (`ArrayList`, `Hashtable`, `DictionaryEntry`)                    |
| Large struct passed by value                           | `struct` with more than 4 fields passed as a method parameter without `in`, `ref`, or `readonly`                                      |
| `IEnumerable<T>` enumerated multiple times             | A local `IEnumerable<T>` variable used in two or more `foreach`/LINQ chains without a `ToList()`/`ToArray()` materialization first    |
| `Regex` compiled per-call                              | `new Regex(...)` inside a method body instead of a `static readonly` field (or `[GeneratedRegex]` in .NET 7+)                         |

### LINQ and collection patterns

| Problem                                               | How to detect                                                                                                  |
|-------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| `.Count() > 0` instead of `.Any()`                    | Grep `\.Count\(\)\s*[>!]=\s*0` — `.Any()` short-circuits; `.Count()` enumerates fully                          |
| `.Count` on `IEnumerable<T>` (non-collection)         | `.Count\(\)` called on a type that does not implement `ICollection<T>` — full enumeration every call           |
| N+1: query/lookup inside loop                         | `foreach`/`for` bodies containing `Dictionary.TryGetValue`, `List.Find`, `Where(...).First`, or database calls |
| `.FirstOrDefault()` then `.Value` / null check        | `.FirstOrDefault()` result used without null guard — use `.TryGetFirst()` or a null check before dereference   |
| LINQ `OrderBy` + `First` instead of `MinBy`           | `.OrderBy(x => x.Prop).First()` — use `.MinBy(x => x.Prop)` (.NET 6+) which is O(n) not O(n log n)             |
| `Distinct()` before `Where()` instead of after        | `.Distinct().Where(...)` — filter first to reduce the set before deduplication                                 |
| `Dictionary` lookup done twice                        | `ContainsKey` check followed by `dictionary[key]` — use `TryGetValue` instead                                  |
| `HashSet` / `Dictionary` not used for membership test | `List.Contains(x)` in a hot path where the collection is populated once and queried many times                 |

### I/O and resource patterns

| Problem                                         | How to detect                                                                                                       |
|-------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| Sync I/O on async code path                     | `File.ReadAllText`, `File.WriteAllText`, `StreamReader.ReadToEnd`, `HttpClient.Send` (non-async) in `async` methods |
| `HttpClient` instantiated per-call              | `new HttpClient(...)` inside a method body — use `IHttpClientFactory` or a static/singleton instance                |
| `IDisposable` not disposed                      | `new` of a type implementing `IDisposable` (streams, connections, writers) without `using` or explicit `Dispose()`  |
| `Stream` read without buffer                    | Reading a stream byte-by-byte or with no `BufferedStream` wrapper in a performance-sensitive path                   |
| File/DB opened and not closed on exception path | `try` block opening a resource with no `finally` or `using` to guarantee closure                                    |
| Synchronous database call in async service      | `DbContext.SaveChanges()` / `DbContext.Find()` (non-async) inside an `async Task` method                            |

### Caching patterns

| Problem                                       | How to detect                                                                                                                 |
|-----------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| Expensive computation repeated per-call       | Methods without caching that read config, perform heavy computation, or query a data source on every invocation in a hot path |
| `IMemoryCache` / `IDistributedCache` not used | Services injected with `IConfiguration` or a repository that is called identically on every request with no cache wrapper     |
| Cache key not deterministic                   | Cache keys built from `DateTime.Now`, `Guid.NewGuid()`, or mutable objects instead of stable, input-derived values            |
| No cache expiry set                           | `IMemoryCache.Set(key, value)` without `MemoryCacheEntryOptions` specifying `AbsoluteExpiration` or `SlidingExpiration`       |
| `lock` on a shared cache dictionary           | `lock (_cache)` around a `Dictionary` used as a cache — use `ConcurrentDictionary` or `IMemoryCache`                          |

### Concurrency and thread safety patterns

| Problem                                         | How to detect                                                                                                          |
|-------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| `lock` on `this` or a public object             | `lock (this)` or `lock (somePublicField)` — use a private `readonly object _lock = new()`                              |
| Non-thread-safe collection used across threads  | `List<T>`, `Dictionary<TK,TV>`, or `Queue<T>` written from multiple threads without a lock or `Concurrent*` equivalent |
| `static` mutable field without synchronization  | `static` non-readonly field of a mutable type with writes in non-constructor methods and no `lock` or `Interlocked`    |
| `Lazy<T>` without thread-safety mode            | `new Lazy<T>(factory)` without specifying `LazyThreadSafetyMode` in a multi-threaded context                           |
| `volatile` used as substitute for `Interlocked` | `volatile` on a numeric field that is incremented/decremented — `volatile` does not make compound operations atomic    |

### Exception handling patterns

| Problem                                       | How to detect                                                                                                                                    |
|-----------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| `catch (Exception)` swallowing all exceptions | `catch (Exception)` or `catch` blocks with empty body or only a log statement — no rethrow                                                       |
| Exception used for control flow               | `try`/`catch` wrapping `int.Parse`, `Dictionary[key]`, or `File.Open` where a `TryParse`/`TryGetValue`/`File.Exists` check would avoid the throw |
| `throw ex` instead of `throw`                 | Grep `throw \w` (non-bare throw) — resets stack trace; use bare `throw`                                                                          |
| `finally` with `return`                       | `return` statement inside a `finally` block — swallows exceptions from the `try`/`catch`                                                         |

### Dependency injection and service lifetime patterns

| Problem                                                | How to detect                                                                                            |
|--------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| Captive dependency (scoped injected into singleton)    | `Singleton` service constructor taking a parameter whose registered lifetime is `Scoped` or `Transient`  |
| `IServiceProvider` resolved inside service constructor | `provider.GetService<T>()` called in a constructor — delays resolution errors and hides dependencies     |
| `new` used for services that should be injected        | `new SomeService(...)` inside a class that is itself DI-registered — bypasses lifetime management        |
| `HttpContext` captured in singleton                    | `IHttpContextAccessor.HttpContext` stored in a field on a singleton service                              |
| Transient `IDisposable` not released                   | Transient service implementing `IDisposable` resolved via `IServiceProvider` without wrapping in a scope |

---

## Step 3 — Compile findings

Group findings by category. Count totals. Prepare this structured summary:

```
## Audit results: {PROJECT_NAME}

Project type:    {PROJECT_TYPE}
Project path:    {PROJECT_PATH}
Test root:       {TEST_ROOT}
Caller context:  {EXTRA_CONTEXT | "(none)"}

Issues found: N total
  Async/Threading:     N
  Memory allocation:   N
  LINQ/Collections:    N
  I/O & Resources:     N
  Caching:             N
  Concurrency:         N
  Exception handling:  N
  DI & Lifetimes:      N

### Issues

**Async / Threading**
- `ClassName::Method()` at `path/File.cs:10-25` — description
[...]

**Memory allocation**
[...]

**LINQ / Collections**
[...]

**I/O & Resources**
[...]

**Caching**
[...]

**Concurrency**
[...]

**Exception handling**
[...]

**DI & Lifetimes**
[...]
```

Omit any category with zero findings.

---

## Step 4 — Invoke feature-planning

Hand off to the **feature-planning skill** with the full audit summary as context. Use the following as the feature
description passed to feature-planning (feed it programmatically — do not ask the user to retype it):

---

> Optimization plan for `{PROJECT_NAME}` (`{PROJECT_PATH}`).
>
> Project type: `{PROJECT_TYPE}`
>
> This is NOT a new feature — it is a performance optimization plan for an existing C# project. The plan must follow the
> standard feature-planning plan structure with these overrides:
>
> **Replace "Implementation steps" with two phases:**
>
> **Phase 0 — Baseline test coverage (mandatory, non-negotiable)**
> - Run existing test suite filtered to this project. Record all passing tests.
> - If any pre-existing failures exist, stop — they must be fixed before optimization work begins.
> - For every issue in "Issues addressed" with no existing test pinning current behavior, write an xUnit or NUnit
    > baseline test.
> - Baseline tests must assert current (pre-optimization) behavior, not desired behavior.
> - Commit baseline tests separately before Phase 1: `test({project}): baseline tests before optimization`
> - Re-run suite. All tests including new baselines must pass before proceeding.
>
> **Phase 1 — Optimizations (one numbered step per issue)**
> - Each step: names file and method, shows exact before/after code snippet, includes a grep/search command to verify no
    > other callers are broken.
> - After every individual step: run the test suite. A single failing test = that step is a failure. Revert and fix
    > before continuing to the next step.
> - One PR per phase.
>
> **Hard constraints to embed in the plan:**
> 1. Every issue cites exact file path and line number range — no approximations.
> 2. Every fix includes a working code snippet using the project's own namespace and conventions.
> 3. Phase 0 is non-negotiable. No Phase 1 step ships without green baseline tests.
> 4. A single test failure after any Phase 1 step = hard stop. Revert, fix, re-run.
> 5. No new infrastructure dependencies (no new NuGet packages unless zero-dependency and widely adopted).
> 6. Do not touch files outside `{PROJECT_PATH}` except test files for code inside it.
> 7. `Task.Result` / `.Wait()` → always replace with `await`. No exceptions.
> 8. `async void` outside event handlers → always replace with `async Task`. No exceptions.
> 9. `.Count() > 0` / `.Count() != 0` → always replace with `.Any()`. No exceptions.
> 10. `new HttpClient()` per-call → always replace with `IHttpClientFactory` or a singleton. No exceptions.
> 11. Every `IDisposable` `new`-ed in a method must be wrapped in `using`. No exceptions.
> 12. `string` concatenation in a loop → always replace with `StringBuilder`. No exceptions.
> 13. `ContainsKey` + `dictionary[key]` → always replace with `TryGetValue`. No exceptions.
> 14. `lock (this)` or `lock` on a public field → always replace with a `private readonly object _lock = new()`. No
      exceptions.
> 15. Captive dependencies (scoped/transient injected into singleton) → fix the registration lifetime; do not change the
      > consuming class unless the fix requires it. The plan step must name the DI registration file and the exact
      > `AddSingleton`/`AddScoped`/`AddTransient` call to change.
> 16. Never recommend switching to manual memory management, unsafe code, or `stackalloc` unless the audit explicitly
      > found a hot-path allocation in a profiler-confirmed bottleneck.
> 17. Never recommend partial model selects or projection-only queries as a blanket optimization — only flag if the
      > projected result is the only consumer and the full model is provably unused.
>
> **Out of scope:** New infrastructure dependencies, database schema changes, files outside `{PROJECT_PATH}`.
>
> **Caller-supplied context** (treat as authoritative — may describe issues not discoverable by static analysis):
>
> {EXTRA_CONTEXT | "(none provided)"}
>
> **Audit findings to address:**
>
> {FULL_AUDIT_SUMMARY_FROM_STEP_3}

---

The feature-planning skill handles the rest: discovers the planning directory, drafts the plan, applies review lenses,
iterates with the user, and writes the final agent-ready plan to disk.