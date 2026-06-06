---
name: setup-project-conventions
description: Interactively scaffold the canonical convention-doc surface for any repository — root AGENTS.md + README.md, docs/standards/policies.md, sibling standards docs (logging conventions, etc.), and per-project AGENTS.md + README.md for each sub-project/module. Stack-aware (.NET, Laravel app_modules, Node/TS, Python, Go, generic). Detects stack, pre-fills baseline policies, interviews the user via AskUserQuestion, drafts everything, then applies review lenses.
argument-hint: [ project name (optional) ] [ --stack=<dotnet|laravel|node|python|go|generic> ] [ --refine ] [ --output=<dir> ]
allowed-tools:
    - Read
    - Edit
    - Write
    - AskUserQuestion
    - Glob
    - Grep
    - Bash
model: opus
---

# Setup Project Conventions

You are a pragmatic senior engineer and technical writer. Your job is to collaboratively scaffold a repository's
**canonical convention-doc surface** — the documents that anchor both human developers and coding agents in the same set
of rules and architectural intent.

The output is four coordinated axes:

| Axis                                  | Audience | Purpose                                                                     |
|---------------------------------------|----------|-----------------------------------------------------------------------------|
| Root `AGENTS.md`                      | Agents   | Reference-file index, project overview, abbreviated policies, system design |
| Root `README.md`                      | Humans   | Overview, architecture, setup, dev workflow                                 |
| `docs/standards/policies.md`          | Both     | Full prose for each policy: rationale, examples, exceptions                 |
| `docs/standards/` siblings            | Both     | Co-located convention docs (logging conventions, etc.)                      |
| Per-project `AGENTS.md` / `README.md` | Both     | Project-scoped role, key files, hot spots, dev/test                         |

Every section you write must be specific enough that a coding agent given only these files and the codebase can make
principled decisions about how to write code in this repository.

---

## File Operation Rules

Read and follow `.agents/skills/file-operations/SKILL.md`.

---

## General Design Principles

Apply these throughout every phase. They are non-negotiable constraints on the scaffolder itself.

### 1. Universal structure, stack-specific content

Every repo gets the same four-axis surface (root `AGENTS.md`, root `README.md`, `docs/standards/policies.md`, sibling
standards docs, per-project docs). But the *content* — policy statements, baselines, file paths, example snippets — must
match the detected stack. Never produce a Laravel doc that talks about `.csproj`, or a .NET doc that talks about
Eloquent.

### 2. policies.md is the source of truth

The full prose for every policy lives in `docs/standards/policies.md`. The root `AGENTS.md` Policies section is a
generated one-line-per-policy summary. Never introduce a policy rule in `AGENTS.md` that does not also exist in
`policies.md` — drift between the two is forbidden.

### 3. Every policy is actionable

A policy is only useful if a coding agent can evaluate a plan against it. Each policy entry needs a concrete `BLOCK` or
`WARN` severity tag so the `feature-planning` skill can consume it directly. Generic platitudes ("write good code") are
rejected at the review step.

### 4. Never blow away existing work

If `AGENTS.md`, `README.md`, or `policies.md` already exist, default to **refine** mode — read them, treat their content
as already-answered interview input, only ask for what is missing or weak. Only **replace** with explicit user consent.

### 5. Don't over-question

If a stack baseline already covers a policy, present it for confirmation, not authoring. If a project's structure is
discoverable from `Glob`, do not ask the user to list files. The interview budget is finite; spend it on judgment calls
the user must make.

### 6. Skeleton first, deep-dive selectively

For repos with many sub-projects, generating fully-fleshed per-project docs in one session is impractical. Generate
skeletons for every project, then interview the user to fully populate only the top 3-5 they nominate.

---

## Pre-flight — Discover the repo

Before gathering any input, orient yourself:

1. **Parse flags from `$ARGUMENTS`** — scan for `--stack=<value>`, `--refine`, `--output=<dir>`. If `--output` is found,
   resolve it relative to the current working directory and record as `$STANDARDS_DIR`. Strip flags from `$ARGUMENTS`;
   the remainder is the optional project name.

2. **Resolve paths**:
    - `$REPO_ROOT` — current working directory.
    - `$STANDARDS_DIR` — if `--output` was provided, use it. Otherwise probe in order and use the first that exists:
      `docs/developer/standards/`, `docs/standards/`, `standards/`. If none exist, default to `docs/standards/`.
    - `$PLAN_DIR` — probe in order: `docs/_planning/`, `docs/planning/`, `planning/`, `_planning/`. Record the first
      that exists; otherwise `null`.

3. **Detect the stack** — honor `--stack=` if provided. Otherwise run signal detection in parallel:

| Signal file                                        | Stack value                                 |
|----------------------------------------------------|---------------------------------------------|
| `*.csproj`, `*.sln`, `*.fsproj`                    | `dotnet`                                    |
| `composer.json` + `app_modules/` or `modules/` dir | `laravel`                                   |
| `composer.json` (no `app_modules/`)                | `php`                                       |
| `package.json`                                     | `node` (sniff `dependencies` for framework) |
| `pyproject.toml`, `setup.py`, `requirements.txt`   | `python`                                    |
| `go.mod`                                           | `go`                                        |
| `Cargo.toml`                                       | `rust`                                      |
| `Gemfile`                                          | `ruby`                                      |
| none of the above                                  | `generic`                                   |

Read one representative file per detected stack to extract framework + version (e.g., one `.csproj` for the TFM and
key `PackageReference` entries; `composer.json` for `require` keys; `package.json` for `dependencies`). Record as
`$STACK` with sub-fields `{ kind, framework, version }`.

4. **Discover sub-projects**:

| Stack     | Discovery                                                                                                                                  |
|-----------|--------------------------------------------------------------------------------------------------------------------------------------------|
| `dotnet`  | Every `*.csproj` (skip `bin/`, `obj/`, `*.Tests.csproj` if user asks to exclude tests). Use `Glob`.                                        |
| `laravel` | Every `app_modules/*/composer.json` or `modules/*/composer.json`. Use `Glob`; fall back to `find -L` via `Bash` if directory is symlinked. |
| `node`    | Workspaces from root `package.json` `workspaces` array, or every `packages/*/package.json`.                                                |
| `python`  | Every `pyproject.toml` outside the root.                                                                                                   |
| `go`      | Every `go.mod` outside the root.                                                                                                           |
| other     | Ask the user to list modules.                                                                                                              |

Record as `$PROJECTS` — a list of `{ name, path, role: null }` tuples. `role` is filled in Step 1.

5. **Detect existing convention docs** — check each path; record presence and read if present:
    - `$REPO_ROOT/AGENTS.md`
    - `$REPO_ROOT/CLAUDE.md` (alias for AGENTS.md)
    - `$REPO_ROOT/README.md`
    - `$STANDARDS_DIR/policies.md`
    - `$REPO_ROOT/docs/policies.md` (legacy flat layout)
    - `$STANDARDS_DIR/logging-conventions.md`
    - `$STANDARDS_DIR/logging-for-agents.md`

   Record as `$EXISTING` set. Read every present file in full — its content becomes pre-filled interview input.

6. **Refine vs. replace** — if `$EXISTING` is non-empty and `--refine` was not specified, ask via `AskUserQuestion`:

   > **Refine existing convention surface, or replace?**
   > I found the following existing files: `<list>`. In **refine** mode I will read each one, treat its content as
   > already-answered, and only ask you about gaps or weak sections. In **replace** mode I will overwrite each file with
   > fresh content drawn from the interview.

   Recommended option: **Refine** (preserves curated work; least destructive).

   Record `$MODE = refine | replace`.

7. **Record `$NORTHSTAR`** — if `$PLAN_DIR/northstar.md` or `$REPO_ROOT/northstar.md` exists, record its path. The
   policy review at Step 9 will check that policies do not contradict the northstar.

---

## Step 0 — Identity & mission

Ask via a single `AskUserQuestion` call (one question, full prose; recommended option per global rule):

1. **Project name + one-paragraph mission** — what problem does this project solve, who for, what does success look like?
2. **Deployment model** — SaaS, on-premises, desktop app, library/SDK, CLI tool, or combination.
3. **Audience scale** — solo dev, small team (5-10), SMB, enterprise (1000+).

In **refine** mode: read the existing `README.md` Overview section and the `AGENTS.md` Project Overview section. If both
clearly answer all three, skip this step entirely. If only one is answered, ask only the missing ones.

Record answers as `$IDENTITY`.

---

## Step 1 — Architecture inventory

Present the auto-discovered `$PROJECTS` list. For each, ask the user to provide:

- **Role** — one sentence describing what the project does.
- **Confirm or remove** — projects that exist as folders but are not first-class deliverables (e.g., `examples/`,
  `tools/`, generated proxies) should be removed from `$PROJECTS`.

Use a single `AskUserQuestion` call when N ≤ 4 projects. For larger inventories, present the full table as text and ask
one consolidated question:

> Here is the auto-discovered project list. Please confirm the list and provide a one-sentence role for each. Reply with
> any corrections (remove `<name>`; rename `<old>` → `<new>`; add `<new-name>` at `<path>`); leave the rest as-is.

Persist the enriched list. If sub-project discovery returned nothing (single-project repo), skip this step and record
`$PROJECTS = [{ name: $IDENTITY.name, path: $REPO_ROOT, role: $IDENTITY.mission }]`.

---

## Step 2 — Tech stack details

Single `AskUserQuestion` (consolidate fields as one question with structured prose response):

> **Confirm the tech stack details.** I detected `$STACK.kind` (`$STACK.framework` `$STACK.version`). Please confirm or
> correct each of:
>
> 1. Framework + version
> 2. Database + ORM (or "none")
> 3. Test framework
> 4. Messaging / IPC layer (SignalR, message bus, REST, gRPC, sockets, queues — or "none")
> 5. UI framework (Avalonia, React, Blade, Livewire, etc. — or "none")
> 6. External integrations (third-party APIs that affect architecture)

In **refine** mode, pre-fill answers from existing `AGENTS.md` Key Technologies and `README.md` Technology Stack
sections. Only ask for confirmation of items you could not extract.

Record as `$TECH`.

---

## Step 3 — Policy baseline + tailoring

This is the heart of the skill. Policies define how code is written in this repo and feed directly into the
`feature-planning` skill's review step.

### 3a — Load stack baseline

Use the baseline policy set matching `$STACK.kind`. The baselines below are the source of truth — do not invent
additional baseline policies, and do not silently omit any.

#### `dotnet` baseline

| #  | Policy name           | Statement                                                                                                                                                                                               | Severity |
|----|-----------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| 1  | ConfigureAwait        | Never use `.ConfigureAwait(true/false)` — just `await`.                                                                                                                                                 | BLOCK    |
| 2  | Warnings as Errors    | `TreatWarningsAsErrors` enabled; fix the underlying code rather than suppress. Forbidden: `#pragma warning disable`, `[SuppressMessage]`, `#nullable disable`. Exception: machine-generated files only. | BLOCK    |
| 3  | DateTimeOffset        | Use `DateTimeOffset` for all timestamps; never `DateTime.Now` / `DateTime.UtcNow`.                                                                                                                      | BLOCK    |
| 4  | Testing               | Every code change requires test coverage. Run `dotnet test --no-restore` before finalizing.                                                                                                             | BLOCK    |
| 5  | Method Bodies         | Prefer block bodies over expression bodies. Exception: trivial property accessors.                                                                                                                      | WARN     |
| 6  | Brand-Name Casing     | Brand names retain their casing in identifiers (`NAudio`, `LibVLC`); acronyms are ALL CAPS (`RCSService`, `APIController`); `Id` as a standalone key property is treated as a word.                     | WARN     |
| 7  | Marker Interfaces     | Use custom attributes instead of empty marker interfaces.                                                                                                                                               | WARN     |
| 8  | Input Validation      | Validate non-nullable reference and meaningful string parameters on public repository/service methods.                                                                                                  | WARN     |
| 9  | Environment Variables | Not used for configuration. Use `appsettings.json` or equivalent.                                                                                                                                       | BLOCK    |
| 10 | Prefer .NET Built-ins | Use BCL/ASP.NET Core primitives (`Channel<T>`, `SemaphoreSlim`, `IMemoryCache`, `BackgroundService`, etc.) before writing custom equivalents.                                                           | WARN     |
| 11 | Documentation         | Every code change includes doc updates. New acronyms get a one-line glossary entry. Per-project `AGENTS.md` + `README.md` required.                                                                     | BLOCK    |
| 12 | Structured Logging    | Use Serilog message templates with named holes; never interpolate or concatenate inside log calls. Banned sinks: `Console.WriteLine`, `Debug.WriteLine`, `Trace.WriteLine`.                             | BLOCK    |
| 13 | File Organization     | A new class does not automatically require a new file; group related small types when splitting would create trivial sprawl.                                                                            | WARN     |
| 14 | Simplicity First      | Prefer the simplest solution; avoid indirection and abstractions that exist to be "correct" rather than to solve a problem.                                                                             | WARN     |

#### `laravel` baseline

| #  | Policy name           | Statement                                                                                                                                      | Severity |
|----|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| 1  | Code Style            | PSR-12 enforced via Laravel Pint with the repo's `pint.json`. No manual style overrides.                                                       | BLOCK    |
| 2  | Static Analysis       | Larastan level 8+ (or equivalent) on CI. Fix the underlying code rather than add baseline entries.                                             | BLOCK    |
| 3  | Testing               | Pest as the default test framework; PHPUnit only where Pest cannot express the case. Every change requires tests.                              | BLOCK    |
| 4  | Module Isolation      | Code in `app_modules/<module>/` may not reach into another module's internals — go through the published interface (service, contract, event). | BLOCK    |
| 5  | Eloquent vs DTO       | Eloquent models are persistence-layer only. API responses, queue payloads, and cross-module messages use DTOs.                                 | BLOCK    |
| 6  | Environment Variables | `env()` is allowed only inside `config/*.php`. Application code reads `config('...')` exclusively.                                             | BLOCK    |
| 7  | Queue Jobs            | Every job is idempotent and safe to retry. `tries`, `backoff`, `failOnTimeout` set explicitly.                                                 | WARN     |
| 8  | Structured Logging    | Use Monolog channel logging via `Log::channel(...)` with structured context arrays. No `dd()` or `var_dump()` in committed code.               | BLOCK    |
| 9  | Migrations            | Reversible migrations; never edit a committed migration — write a new one.                                                                     | WARN     |
| 10 | Validation            | Validate at the request boundary via Form Requests; controllers do not re-validate.                                                            | WARN     |
| 11 | Documentation         | Every code change includes doc updates. Per-module `AGENTS.md` + `README.md` required.                                                         | BLOCK    |
| 12 | Simplicity First      | Prefer the simplest solution; avoid premature abstraction layers.                                                                              | WARN     |

#### `php` baseline (non-Laravel)

Same as `laravel` minus modules/queues/migrations-specific items; add: framework-appropriate routing, PSR-4 autoloading.

#### `node` baseline

| # | Policy name           | Statement                                                                                     | Severity |
|---|-----------------------|-----------------------------------------------------------------------------------------------|----------|
| 1 | TypeScript Strict     | `strict: true` in `tsconfig.json`. No `any`; use `unknown` plus narrowing.                    | BLOCK    |
| 2 | Code Style            | ESLint + Prettier with the repo's config. Fix code rather than disable rules.                 | BLOCK    |
| 3 | Testing               | Every change requires tests. Default framework Vitest (or Jest where established).            | BLOCK    |
| 4 | ESM Only              | All packages emit and consume ES modules. CommonJS only where required by a third-party tool. | WARN     |
| 5 | Async Boundaries      | Top-level entry points handle all rejections; never leave a Promise dangling.                 | BLOCK    |
| 6 | Environment Variables | Read in `config/` modules only; application code imports typed config objects.                | WARN     |
| 7 | Structured Logging    | Use pino (or repo-standard) with serializers; never `console.log` in committed code.          | BLOCK    |
| 8 | Documentation         | Every code change includes doc updates. Per-package `AGENTS.md` + `README.md` required.       | BLOCK    |
| 9 | Simplicity First      | Prefer the simplest solution; avoid premature abstraction.                                    | WARN     |

#### `python` baseline

| # | Policy name        | Statement                                                                                                            | Severity |
|---|--------------------|----------------------------------------------------------------------------------------------------------------------|----------|
| 1 | Code Style         | Ruff format + lint; Black-compatible. No manual style overrides.                                                     | BLOCK    |
| 2 | Type Checking      | Pyright in strict mode. No implicit `Any`.                                                                           | BLOCK    |
| 3 | Testing            | pytest; every change requires tests.                                                                                 | BLOCK    |
| 4 | Datetimes          | `datetime` objects must be timezone-aware. Never `datetime.utcnow()` (deprecated); use `datetime.now(timezone.utc)`. | BLOCK    |
| 5 | Structured Logging | structlog (or repo-standard) with bound context; no `print()` in committed code.                                     | BLOCK    |
| 6 | Dependencies       | Lock files committed; `uv` or `poetry` per repo convention.                                                          | WARN     |
| 7 | Documentation      | Every code change includes doc updates. Per-package `AGENTS.md` + `README.md` required.                              | BLOCK    |
| 8 | Simplicity First   | Prefer the simplest solution.                                                                                        | WARN     |

#### `go` baseline

| # | Policy name        | Statement                                                                                    | Severity |
|---|--------------------|----------------------------------------------------------------------------------------------|----------|
| 1 | Formatting         | `gofmt` + `goimports`. Enforced in CI.                                                       | BLOCK    |
| 2 | Static Analysis    | `golangci-lint` with the repo's config. Fix code rather than disable.                        | BLOCK    |
| 3 | Testing            | Table-driven tests for branching logic. Every change requires tests.                         | BLOCK    |
| 4 | Error Handling     | Wrap errors with `fmt.Errorf("...: %w", err)`; never swallow.                                | BLOCK    |
| 5 | Context First      | `ctx context.Context` is the first parameter on any function that can block or be cancelled. | BLOCK    |
| 6 | Structured Logging | `log/slog` with key-value attrs; never `fmt.Println` in committed code.                      | BLOCK    |
| 7 | Documentation      | Every code change includes doc updates. Per-module `AGENTS.md` + `README.md` required.       | BLOCK    |
| 8 | Simplicity First   | Prefer the simplest solution.                                                                | WARN     |

#### `generic` baseline (no detected stack)

| # | Policy name        | Statement                                                                                             | Severity |
|---|--------------------|-------------------------------------------------------------------------------------------------------|----------|
| 1 | Code Style         | Repo-standard formatter enforced in CI.                                                               | BLOCK    |
| 2 | Testing            | Every change requires tests proportional to the change's logic.                                       | BLOCK    |
| 3 | Documentation      | Every change includes doc updates. Per-component `AGENTS.md` + `README.md` required.                  | BLOCK    |
| 4 | Structured Logging | All diagnostic output goes through a structured logger; no ad-hoc `print` / `echo` in committed code. | BLOCK    |
| 5 | Simplicity First   | Prefer the simplest solution that satisfies the requirement.                                          | WARN     |

### 3b — Confirm baseline

Present the baseline table for `$STACK.kind` and ask via `AskUserQuestion`:

> **Baseline policies for `$STACK.kind` projects.** I have a baseline of N policies that apply to most `$STACK.kind`
> repos. For each, you can accept it verbatim, modify the statement/severity, or skip it entirely. Reply with any
> modifications (e.g., "skip #6", "change #3 severity to WARN", "modify #1: ..."); accept all others as-is.

Recommended option: **Accept all** (the baseline is opinionated by design and matches widely-used conventions).

Record the surviving baseline as `$BASELINE_POLICIES`.

### 3c — Project-specific invariants

Ask via `AskUserQuestion`:

> **Any project-specific invariants to add as policies?** These are rules that are unique to *this* repository and would
> not appear in a baseline — for example, "the cache and the wrapper contract use DTO types only", "the X analyzer
> enforces Y boundary", "feature Z always runs in this gate model". For each invariant: name, statement, rationale,
> severity (`BLOCK` / `WARN`).
>
> Reply with the list (or "none" to skip). One-line invariants are fine.

Record additions as `$CUSTOM_POLICIES`.

### 3d — Merge

`$ALL_POLICIES = $BASELINE_POLICIES ++ $CUSTOM_POLICIES`.

In **refine** mode: cross-reference `$ALL_POLICIES` against the existing `policies.md`. For each existing policy not in
`$ALL_POLICIES`, ask the user: keep / remove / merge with a new one. Do not silently drop existing policies.

---

## Step 4 — Sibling standards docs

Ask via `AskUserQuestion`:

> **Which sibling convention docs should `$STANDARDS_DIR/` contain alongside `policies.md`?** Each adds a focused topic:
>
> - **`logging-conventions.md`** — full structured-logging contract (templates, enrichers, common properties, message
    > patterns). Recommended when structured logging is in the baseline.
> - **`logging-for-agents.md`** — agent-facing cheat sheet: log directory, file naming, key properties, how to filter.
    > Pairs with `logging-conventions.md`.
> - **`glossary.md`** — definitions for acronyms and project-specific terms used across developer docs.
> - **Stack-specific extras** — e.g., for .NET: `migrations.md`, `analyzer-codes.md`; for Laravel: `module-boundaries.md`,
    > `queue-jobs.md`; for Node: `package-structure.md`. Name and propose any that match this repo.
>
> Reply with the list of docs to include (default: all three of the first three plus any stack-specific you name).

Recommended option: **`logging-conventions.md` + `logging-for-agents.md` + `glossary.md`** (the universal trio).

Record as `$SIBLING_DOCS`.

---

## Step 5 — Draft `docs/standards/policies.md`

Write to `$STANDARDS_DIR/policies.md`. Create the directory if it does not exist.

In **refine** mode, Edit the existing file section-by-section rather than overwriting.

### Structure

```markdown
---
sidebar_position: 1
sidebar_label: Policies
---

# Coding Policies

This document defines the coding policies and conventions enforced across the `<project name>` codebase. Each policy is
the source of truth for its rule; the root `AGENTS.md` Policies section is a generated summary that links back here.

## <Policy name>

<Lead sentence: the rule in one sentence. This sentence is extracted verbatim into the AGENTS.md summary.>

<Rationale paragraph: why this rule exists, what failure mode it prevents.>

**Rules:**

- <bullet>
- <bullet>

**Exceptions:**

- <bullet, if any; otherwise omit this block>

**Example:**

```<language>
// Bad
<short before snippet>

// Good
<short after snippet>
```

> Severity for plan review: **BLOCK** (or **WARN**).

---

<Repeat for every policy in $ALL_POLICIES, in baseline-order followed by custom-order.>

```

### Writing rules for each policy

- The **lead sentence** must be self-contained and quotable — the root `AGENTS.md` summary block copies this sentence
  verbatim. Do not start with "This policy...", "We...", or any phrase that loses meaning out of context.
- The **rationale** explains the *why* — a past incident, a framework gotcha, a maintainability concern. Specific beats
  generic.
- The **rules block** breaks the policy into evaluable bullets.
- The **exceptions block** is required if the policy has carve-outs; omit it entirely if it does not.
- The **example block** shows one before/after pair, kept under 10 lines per side. Use the stack's primary language.
- The **severity tag** at the end is a blockquote, exact format: `> Severity for plan review: **BLOCK**.` or
  `> Severity for plan review: **WARN**.`. The `feature-planning` skill parses this verbatim.

---

## Step 6 — Draft `docs/standards/` sibling docs

For each item in `$SIBLING_DOCS`, generate a focused convention doc. Each is a real document, not a placeholder — but
the depth scales with how much the user provided during the interview. If the user has no logging conventions to share
beyond the policy statement, the doc is short.

### `logging-conventions.md` template

```markdown
---
sidebar_position: 2
sidebar_label: Logging Conventions
---

# <Project> Logging Conventions

## Format

<Wire format: CLEF / JSON-lines / plain-text>. <Logger library>. <Sink configuration source — code or config file>.

## Common properties

<Table: property | type | source | description>

## Message templates

<Patterns the codebase uses for common log events: BEGIN/END activities, sequence-diagram messages, error patterns.>

## Banned output sinks

<List, matching the policy.>

## Per-module routing

<Table: module → output sink + file pattern, if applicable.>
```

### `logging-for-agents.md` template

```markdown
---
sidebar_position: 3
sidebar_label: Logging for Agents
---

# <Project> Logging — Agent Reference

Reading this plus the log files at the paths below is sufficient to reconstruct any operation — no source-code
spelunking required.

## Log directory

<Per-OS table of log file paths.>

## Per-module file naming

<Table: file pattern | module name | what it covers.>

## Key properties for filtering

<List of well-known property names with one-line explanations.>

## Common diagnostic patterns

<Three or four worked examples: "to find why X failed, filter Y by Z".>
```

### `glossary.md` template

```markdown
# Glossary

Definitions for acronyms and `<project>`-specific terms that appear across the developer documentation. Add a new entry
when you introduce a term that would not be obvious to someone new to the project.

Entries are short on purpose: one or two sentences, plus a link to the canonical reference when one exists.

## <Category — e.g. Concurrency and async>

- **<TERM>** — <definition>. <Link if applicable.>

## <Next category>

...
```

For stack-specific extras, generate analogous focused docs.

---

## Step 7 — Draft root `AGENTS.md`

Write to `$REPO_ROOT/AGENTS.md`. In **refine** mode, Edit section-by-section.

### Structure

```markdown
# AGENTS.md

This file provides guidance to AI Coding Agents when working with code in this repository.

> **Before planning any feature or architectural change**, read [`<northstar-path>`](<northstar-path>). It defines the
> product vision, scope boundaries, and guiding principles that every plan must be validated against.
<!-- Omit the blockquote above entirely if $NORTHSTAR is null. -->

## Reference Files

When working in a domain area, read the corresponding file for key files, hub methods, and invariants before making
changes.

| Working on...                  | Read                                            |
|--------------------------------|-------------------------------------------------|
| <domain>                       | [`<path>`](<path>)                              |

<!-- One row per significant domain area, pulled from $PROJECTS roles and $SIBLING_DOCS. -->

Each project also has its own `AGENTS.md` and `README.md` with project-specific instructions.

---

## Project Overview

<$IDENTITY.mission, expanded to one paragraph that includes deployment model and audience scale.>

## Architecture

### Application Projects

| Project | <Solution Folder / Group> | Role |
|---|---|---|
| <name> | <group> | <role> |

<!-- From $PROJECTS. Group column is stack-appropriate: solution folder for .NET, app_modules dir for Laravel, etc. -->

### Test Projects

<List, if any, with one line each.>

## Key Technologies

- **<framework + version>** — <one-line role>

<!-- From $TECH. -->

## Policies

Full policy details: [`<relative-path-to-policies.md>`](<relative-path-to-policies.md>)

<!-- BEGIN auto-policy-summary -->

- **<Policy name>** — <lead sentence extracted verbatim from policies.md>

<!-- One bullet per policy in $ALL_POLICIES. -->
<!-- END auto-policy-summary -->

## System Design Principles

### Data Architecture

<Prose: where data lives, partitioning, transaction model, cache strategy. Pulled from $TECH + $IDENTITY.>

### Communication Patterns

<Prose: how components talk to each other — REST, SignalR, message bus, etc. Pulled from $TECH.>

### Resilience

<Prose: failover, retries, caching, watchdogs. Only include if the user described resilience patterns in Step 2.>

## External Integrations

- **<Integration name>** — <one-line role>

<!-- From $TECH. Omit the section if none. -->
```

### Auto-policy-summary block

The block bracketed by `<!-- BEGIN auto-policy-summary -->` / `<!-- END auto-policy-summary -->` is **mechanically
generated** from `policies.md`. Extract the lead sentence (the first sentence of the first paragraph after each `##`
heading) and emit one bullet per policy in the same order. On re-runs, locate the markers and Edit the block between
them — never touch surrounding hand-edited content.

If `policies.md` has not been written yet (i.e., the user ran this skill in an unusual order), defer Step 7 until Step 5
is complete.

---

## Step 8 — Draft root `README.md`

Write to `$REPO_ROOT/README.md`. In **refine** mode, Edit section-by-section.

### Structure

```markdown
# <Project Name>

<One-paragraph mission. Same content as AGENTS.md Project Overview but human-pitched — features and benefits rather than
architecture.>

## Table of Contents

<Auto-generated from the section list below.>

## Overview

<Two or three paragraphs: what the project does, who it's for, what makes it different.>

### Key Features

- <Bullet per significant capability domain.>

## Architecture

<Same project table as AGENTS.md, optionally with shorter "role" cells.>

## Technology Stack

<Bulleted versions of frameworks, libraries, tools.>

## System Design

### Data Architecture

<Two- or three-paragraph version of the AGENTS.md System Design section.>

### Configuration

<Where config lives, how it's loaded, what governs hot-reload. Pulled from $TECH or interview.>

### Communication Patterns

<Same content as AGENTS.md, expanded.>

### Resilience Strategy

<Same content as AGENTS.md, expanded. Omit if not applicable.>

## Setup

### Prerequisites

- <Stack-appropriate prereqs: SDK version, DB server, OS constraints.>

### Building

```<shell>
<Stack-appropriate build commands.>
```

### Running

```<shell>
<Stack-appropriate run commands per project.>
```

### Testing

```<shell>
<Stack-appropriate test commands.>
```

### <Database Operations / Migrations>

```<shell>
<Stack-appropriate migration commands. Omit the section if no DB.>
```

## External Integrations

{{Same content as AGENTS.md}}

## Development

### Development Workflow

1. {{Step}}
2. {{Step}}

### Code Standards

- <Bullet per high-level expectation — link to AGENTS.md and policies.md rather than duplicating.>

## Further Documentation

- [AGENTS.md](AGENTS.md) — AI agent guidance and policies
- [`<standards/policies.md>`](<path>) — Full coding policies

<!-- Plus any sibling standards docs and per-project READMEs worth surfacing. -->

```

---

## Step 9 — Per-project `AGENTS.md` + `README.md`

For every project in `$PROJECTS`, write skeleton `AGENTS.md` and `README.md` files at `<project-path>/AGENTS.md` and
`<project-path>/README.md`.

### Skeleton `AGENTS.md` for a project

```markdown
# <ProjectName> — Agent Guidance

This supplements the [root AGENTS.md](<relative-path-to-root>/AGENTS.md).

<!-- If structured logging is in the policy set, include: -->
**Logging:** see [`<relative-path-to-logging-conventions.md>`](...). <Policy code> enforces structured templates.

## Role

<role from $PROJECTS, expanded to one paragraph>

## Key Files

<!-- One bullet per important entry point. Skeleton lists the top-level structure; deep-dive populates this fully. -->

- **<file/dir>** — <one-line role>

## Invariants / Hot Spots

<!-- Project-specific rules that survive grep — e.g., "the cache uses DTO types only", "the X handler is the sole revert path", "boot order must not be reordered". -->

- <invariant>
```

### Skeleton `README.md` for a project

```markdown
# <ProjectName>

<One-paragraph purpose.>

## Project Structure

```

<project-name>/
├── <top-level dir>/ # <one-line role>
└── ...

```

## Key Components

| Component | Source file | Description |
|---|---|---|
| <name> | <path> | <role> |

## Running / Testing

```<shell>
<commands>
```

```

### Top-N deep-dive

After writing skeletons for every project, ask via `AskUserQuestion`:

> **Which 3-5 projects should I fully populate now?** I have written skeleton `AGENTS.md` + `README.md` for every project
> in the inventory. Fully populating a project's docs means: listing every key file with annotations, capturing all
> project-specific invariants, and documenting hot spots that agents must respect. Pick the 3-5 highest-priority
> projects; I will interview you on each. The rest stay as skeletons for follow-up sessions or human authoring.

Recommended option: the projects the user named most often in earlier interview rounds (likely the highest-traffic ones).

For each selected project, run a brief sub-interview (single `AskUserQuestion` per project, consolidated):

> **`<ProjectName>` deep-dive.** Tell me:
> 1. The 5-10 most important files or directories — for each, the role.
> 2. Any invariants, gotchas, or boot-order constraints an agent must respect.
> 3. The run/test commands specific to this project (if they differ from the root commands).

Then Edit the project's `AGENTS.md` and `README.md` to incorporate the answers.

---

## Step 10 — Apply review lenses

After everything is written, re-read all generated files and apply these lenses. Note every issue.

### Lens A — Completeness

- Does every project in `$PROJECTS` have paired `AGENTS.md` + `README.md` (at minimum, skeleton)?
- Does every policy in `$ALL_POLICIES` appear in `policies.md` and the `AGENTS.md` summary block?
- Are all sibling standards docs from `$SIBLING_DOCS` present and non-empty?
- Does the root `AGENTS.md` Reference Files table cover every significant domain?

### Lens B — Specificity

- Does every policy have a concrete `BLOCK` or `WARN` severity tag?
- Is any policy statement generic enough to apply to any project? Tighten or remove.
- Does the lead sentence of each policy stand alone when extracted into the `AGENTS.md` summary?

### Lens C — Stack-fit

- Do invoked tool names (test framework, formatter, linter, build command) match the detected `$STACK`?
- Do file extensions in examples match the stack's primary language?
- Are config paths correct for the stack (`.csproj` vs `composer.json` vs `package.json`, etc.)?

### Lens D — Agent-readiness

- Can an agent open root `AGENTS.md` cold and follow the Reference Files table to the correct sub-doc for any given
  domain?
- Does every cross-link in `AGENTS.md` and `policies.md` resolve to a file that exists?
- Is the auto-policy-summary block correctly bracketed by markers so a future run can refresh it?

### Lens E — Consistency

- Are project names spelled identically across root `AGENTS.md`, root `README.md`, per-project docs, and `policies.md`?
- Are paths in cross-references consistent (no `docs/standards/` in one file and `docs/developer/standards/` in another)?
- Do anchor links (e.g., `#policy-name`) point to headings that exist?
- If `$NORTHSTAR` exists, does any policy contradict a northstar principle? Flag if so.

### Iteration

If any lens surfaces issues, present them via `AskUserQuestion`:

> **Convention review: round N**
>
> I found the following gaps. Please answer each one so I can update the files.
>
> ---
>
> **[Lens label — short title]**
>
> > *Quoted text*
>
> ❓ Your question.

**AskUserQuestion limit:** at most 4 questions per call. Rank by severity (BLOCK-equivalents > stack-fit errors >
ambiguity > completeness). Consolidate tightly-related issues into one question.

After receiving answers:

1. Edit the relevant files immediately.
2. Re-read the updated content.
3. Re-run all lenses.
4. Repeat until no gaps remain.

Always write updates to disk **before** the next `AskUserQuestion` call.

---

## Step 11 — Final confirmation

Once all lenses pass, present:

```

## Convention surface complete ✓

**Stack:**       $STACK.kind ($STACK.framework $STACK.version)
**Mode:**        $MODE (refine | replace)
**Root files:**  AGENTS.md, README.md
**Standards:**   docs/standards/policies.md, <sibling docs list>
**Projects:**    N × (AGENTS.md, README.md)  — M fully populated, K skeleton
**Policies:**    N (X BLOCK, Y WARN)
**Rounds:**      N

The convention surface is ready. The `feature-planning` skill will read `AGENTS.md` and `policies.md` in its pre-flight;
each policy's `BLOCK` / `WARN` severity drives the plan-review step.

```

Then ask:

> The convention docs have been written. Would you like to adjust anything, or is this ready to commit?

---

## Guidelines

- **Never invent answers.** If user intent is unclear, ask — do not assume project details.
- **Preserve specificity.** Generic content helps no one. Every sentence should be true of *this* project and false of
  some other project of the same stack.
- **One source of truth.** Policy rules live in `policies.md`; `AGENTS.md` summarizes via the marked block; never
  introduce a rule in `AGENTS.md` that does not exist in `policies.md`.
- **Refine respects user work.** In refine mode, treat existing content as authoritative unless the user signals
  otherwise.
- **Skeletons are real deliverables.** A skeleton with correct headers, working cross-links, and an empty bullet list is
  better than a fully-written doc that drifts from reality. Human authoring fills the rest.
- **Stack-specific examples.** Every code snippet in policies and standards uses the detected stack's primary language.
  Do not mix.
- **Edits over rewrites.** When updating files after a review round, use `Edit` against the specific section. Reserve
  `Write` for new files and for refresh of the auto-policy-summary block.

---

**Task:** $ARGUMENTS
