---
name: laravel-optimization
description: Audits a Laravel application or composer package module path for performance issues (N+1 queries, unbounded gets, missing cache, sync observers, route closures, fat controllers), then delegates to the feature-planning skill to produce a self-contained, phased, agent-ready optimization plan. Does NOT execute optimizations. A single failing test in the plan's Phase 0 baseline gate is a hard stop.
argument-hint: "<module-path> [additional context]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(test -f *)
  - Bash(find * -name "*.php" -type f)
  - Bash(cat *)
  - Skill(feature-planning)
  - AskUserQuestion
model: opus
---

# Laravel Optimization Skill

You are an expert Laravel performance engineer. Your job is to **audit** a module path, discover performance issues, and
then invoke the **feature-planning skill** to produce a self-contained, agent-ready optimization plan. You do not
execute any optimization code yourself.

**Input:** `$ARGUMENTS` — the module path to audit (e.g. `app_modules/WebCMS/src`, `app/Services`,
`packages/my-package/src`).

---

## Step 0 — Validate input

Parse `$ARGUMENTS`. Extract:

- `MODULE_PATH` — first positional argument (required). If missing or the path does not exist, abort with:
  ```
  Error: MODULE_PATH is required. Usage: /laravel-optimization <path/to/module> [additional context]
  ```
- `EXTRA_CONTEXT` — everything after the first positional argument (optional). Free-form text the caller provides about
  known issues, architectural decisions, or constraints the automated audit may not discover (e.g. "the Settings model
  is loaded on every request via a middleware", "observers in this module are known to fire during seeding"). Preserve
  it verbatim.

Derive `MODULE_NAME` from the last meaningful path segment (if last segment is `src`, use its parent).

---

## Step 1 — Detect project type

Read `composer.json` at the repo root. Classify the project:

| Signal                                                                   | Classification          |
|--------------------------------------------------------------------------|-------------------------|
| `"type": "library"` OR path is inside `packages/` or `vendor/`           | **Composer Package**    |
| `"laravel/framework"` in `require`/`require-dev`, no `"type": "library"` | **Laravel Application** |
| Both (monorepo: package consumed by a Laravel app)                       | **Monorepo Package**    |

Record as `PROJECT_TYPE`. Scope rules per type:

- **Laravel Application** — out of scope: anything outside `MODULE_PATH`, `legacy/` dir, `vendor/`
- **Composer Package** — out of scope: host application code, `vendor/`
- **Monorepo Package** — out of scope: sibling packages, `app/` and `app_modules/` outside `MODULE_PATH`

Determine test root:

- Application: `tests/` at repo root, or `application/tests/`
- Package: `{MODULE_PATH}/tests/` or nearest `tests/` sibling to `src/`
- Monorepo Package: package-local `tests/` preferred, host app `tests/` as fallback

Emit before continuing:

```
Project type: {PROJECT_TYPE}
Module:       {MODULE_NAME} ({MODULE_PATH})
Test root:    {TEST_ROOT}
```

If classification is ambiguous, state your best guess and the reason, then continue.

---

## Step 2 — Audit the module

Systematically search `MODULE_PATH` for every problem category below. For each hit, **read the actual file to confirm
line numbers before recording**. Never approximate.

Record each finding as:

- **Category**
- **Class::method()** (or class name)
- **File path** (exact, relative to repo root)
- **Line range**
- **One-sentence description of the specific problem**

### Query patterns

| Problem                                 | How to detect                                                                        |
|-----------------------------------------|--------------------------------------------------------------------------------------|
| Unbounded `->get()`                     | `->get()` with no preceding `->limit(` or `chunkById` in the same method body        |
| `->count() > 0` instead of `->exists()` | Grep `->count\(\)\s*(>!=)\s*0`                                                       |
| N+1: query inside loop                  | `foreach`/`for`/`each` blocks containing `->find(`, `->where(`, `->first(`, `->get(` |
| `->load()` after `->get()`              | `->load\(` where the initial query did not use `->with(`                             |

### Async / observer patterns

| Problem                                    | How to detect                                                                                                                                |
|--------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `Artisan::call()` in observer/job/listener | Grep `Artisan::call\(` — check enclosing class type                                                                                          |
| API client re-instantiated per `handle()`  | `new .*Client\(` inside `handle()` method bodies                                                                                             |
| Observer without `$afterCommit`            | Class that is an observer — check for `public bool $afterCommit = true` and the application is not configured to use after commit by default |
| Sync dispatch in model `boot()`            | `dispatch(` or `event(` inside `boot()` with no `->onQueue(`                                                                                 |

### Caching patterns

| Problem                       | How to detect                                                                                       |
|-------------------------------|-----------------------------------------------------------------------------------------------------|
| Expensive query with no cache | `->get()` or `->all()` on settings/config/menu models with no `Cache::remember` wrapper             |
| Cache inside transaction      | `Cache::remember` or `Cache::add` inside `DB::transaction(`                                         |
| No cache invalidation         | `Cache::remember` with a key — check for corresponding `Cache::forget` or `Cache::delete` on writes |

### Routing

| Problem                               | How to detect                                                  |
|---------------------------------------|----------------------------------------------------------------|
| Route closures blocking `route:cache` | `Route::(get\|post\|put\|patch\|delete\|any)\(.*function\s*\(` |

### Architecture

| Problem                                       | How to detect                                                                                                                                                                                                                                |
|-----------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Business logic in controller                  | Multiple queries, conditionals, or service calls directly in controller methods                                                                                                                                                              |
| Business logic in Filament `mount()`          | `function mount\(` body containing query calls                                                                                                                                                                                               |
| Business logic in Blade                       | `@php` blocks containing query calls                                                                                                                                                                                                         |
| `boot()` dispatching sync jobs                | `static::creating\|created\|updated` calling `dispatch(` without `->onQueue(`                                                                                                                                                                |
| Dead Blade views                              | Blade files for routes now served by Inertia/ThemeKit still containing query-heavy `@php` blocks                                                                                                                                             |
| Static self-managing singleton via `::make()` | Grep `protected static .*\$instance` — confirm `::make()` body contains an `isset(static::\$instance)` guard. Skip if class uses `HasMake` trait (`use HasMake`) or implements `IDisposable`. Flag remainder; see disambiguation note below. |

#### Disambiguation — `::make()` singleton vs factory vs DTO

| Signal                                                                                                        | Meaning                                                                                         | Action                             |
|---------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|------------------------------------|
| Class body contains `use HasMake`                                                                             | `HasMake` creates a fresh instance per call via reflection — not a singleton                    | **Skip. Do not flag.**             |
| Class implements `IDisposable`                                                                                | Lifecycle already managed externally                                                            | **Skip. Do not flag.**             |
| Class extends an `Illuminate\` or `Laravel\` base class, OR does not define `::make()` itself                 | `::make()` is a Laravel Framework method (e.g. Eloquent model factory) — not a custom singleton | **Skip. Do not flag.**             |
| Class extends `Spatie\LaravelData\Data`                                                                       | Spatie Laravel Data DTO — `::from()` / `::make()` creates a fresh value object, no shared state | **Skip. Do not flag.**             |
| Class extends `Spatie\DataTransferObject\DataTransferObject`                                                  | Spatie DTO — immutable value object, no static shared state                                     | **Skip. Do not flag.**             |
| Class declared `readonly class` (PHP 8.2+)                                                                    | Immutable value object — all properties are readonly, cannot hold mutable static state          | **Skip. Do not flag.**             |
| `protected static .*\$instance` + `isset(static::\$instance)` guard in `::make()` defined in the class itself | True self-managing singleton, bypasses Laravel container                                        | **Flag as optimization candidate** |

For every flagged class, evaluate **configuration class signals** (≥2 → lower confidence):

1. Class name ends in `Config`, `Settings`, or `Options`
2. All non-constructor public methods return typed config/settings objects with no side effects
3. Has `public static reset()` guarded by `App::environment('testing')`
4. Constructor takes no arguments and wires dependencies via `new` internally

Also evaluate **DTO / Data Object signals** (≥2 → lower confidence):

1. Class name ends in `Data`, `DTO`, `Dto`, `Payload`, or `ValueObject`
2. All non-static public properties are `readonly` (PHP 8.1+)
3. Public methods limited to `from()`, `fromArray()`, `toArray()`, `all()`, `except()`, `only()` — no I/O or side effects
4. Class body contains a `#[MapInputName]`, `#[Computed]`, `#[Hidden]`, or other Spatie Data attribute
5. Constructor only assigns properties — no service calls, no dependency wiring via `new`

Record confidence level (`standard`, `lower — possible configuration class`, or `lower — possible DTO / data object`) alongside each finding. A class may trigger both lower-confidence signals; record both labels.

For **all** flagged singleton findings (regardless of confidence), use `AskUserQuestion` **before** passing findings to
feature-planning to ask the developer whether the preferred fix is `app()->singleton()` or `app()->scoped()` binding in
a service provider.

---

## Step 3 — Compile findings

Group findings by category. Count totals. Prepare this structured summary:

```
## Audit results: {MODULE_NAME}

Project type:    {PROJECT_TYPE}
Module path:     {MODULE_PATH}
Test root:       {TEST_ROOT}
Caller context:  {EXTRA_CONTEXT | "(none)"}

Issues found: N total
  Query patterns:     N
  Async/observer:     N
  Caching:            N
  Routing:            N
  Architecture:       N

### Issues

**Query patterns**
- `ClassName::method()` at `path/file.php:10-25` — description
[...]

**Async / observer**
[...]

**Caching**
[...]

**Routing**
[...]

**Architecture**
[...]
```

Omit any category with zero findings.

---

## Step 4 — Invoke feature-planning

Hand off to the **feature-planning skill** with the full audit summary as context. Use the following as the feature
description passed to feature-planning (feed it programmatically — do not ask the user to retype it):

---

> Optimization plan for `{MODULE_NAME}` (`{MODULE_PATH}`).
>
> Project type: `{PROJECT_TYPE}`
>
> This is NOT a new feature — it is a performance optimization plan for an existing module. The plan must follow the
> standard feature-planning plan structure with these overrides:
>
> **Replace "Implementation steps" with two phases:**
>
> **Phase 0 — Baseline test coverage (mandatory, non-negotiable)**
> - Run existing test suite filtered to this module. Record all passing tests.
> - If any pre-existing failures exist, stop — they must be fixed before optimization work begins.
> - For every issue in "Issues addressed" with no existing test pinning current behaviour, write a PestPHP baseline test
    using `describe()` and `test()` (not `it()`).
> - Baseline tests must assert current (pre-optimization) behaviour, not desired behaviour.
> - Commit baseline tests separately before Phase 1: `test({module}): baseline tests before optimization`
> - Re-run suite. All tests including new baselines must pass before proceeding.
>
> **Phase 1 — Optimizations (one numbered step per issue)**
> - Each step: names file and method, shows exact before/after code snippet, includes a grep/search command to verify no
    other callers are broken.
> - After every individual step: run the test suite. A single failing test = that step is a failure. Revert and fix
    before continuing to the next step.
> - One PR per phase.
>
> **Hard constraints to embed in the plan:**
> 1. Every issue cites exact file path and line number range — no approximations.
> 2. Every fix includes a working code snippet using the module's own namespace and conventions.
> 3. Phase 0 is non-negotiable. No Phase 1 step ships without green baseline tests.
> 4. A single test failure after any Phase 1 step = hard stop. Revert, fix, re-run.
> 5. No new infrastructure dependencies (Redis, SSR, new queue drivers, Elasticsearch).
> 6. Do not touch files outside `{MODULE_PATH}` except test files for code inside it.
> 7. `->count() > 0` → `->exists()`. Always. No exceptions.
> 8. Never cache inside a `DB::transaction()` closure. Cache after commit.
> 9. Observers that perform I/O must have `public bool $afterCommit = true`.
> 10. Never recommend partial model selects (`->select(...)` to limit columns) or partial eager loads (`->with('relation:id,col,...')`). These are not approved optimization patterns. Full models must always be loaded.
> 11. Self-managing singletons (`protected static $instance` + `isset` guard in `::make()` defined in the class itself)
      → register in an existing or new Service Provider's `register()` method using the binding type confirmed via
      `AskUserQuestion` (`app()->singleton()` or `app()->scoped()`), then replace callsites with constructor/method
      injection. The plan step must identify the target Service Provider by name. Configuration-class findings (lower
      confidence) must include a note that the change may be intentional and require developer review before proceeding.
      **Never flag** classes using `HasMake` trait, implementing `IDisposable`, extending an `Illuminate\`/`Laravel\`
      base class, extending `Spatie\LaravelData\Data` or `Spatie\DataTransferObject\DataTransferObject`, declared
      `readonly class`, or where `::make()` is not defined in the class itself. DTO/Data Object findings (lower
      confidence) must include a note that the static property may be a local cache (e.g. memoised computation), not
      shared service state, and require developer review before proceeding.
>
> **Out of scope:** Redis, SSR, Vite, new infrastructure dependencies, files outside `{MODULE_PATH}`.
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
