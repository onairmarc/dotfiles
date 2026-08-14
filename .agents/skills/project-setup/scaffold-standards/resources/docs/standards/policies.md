# Coding Policies

This document is the **index** of the coding policies and conventions enforced across **{{PROJECT_NAME}}**. Each policy lives in its own file under
[`policies/`](./policies/) so an agent (or a human) can load only the policy relevant to the task at hand rather than the whole rule set. Each policy file is the source
of truth for its rule and carries its own statement, rationale, rules, and worked example.

The concrete rules are written for **{{PRIMARY_LANGUAGE}}** on **{{STACK}}**.

Policies are tagged `BLOCK` (a plan that violates the policy must not proceed without an explicit override) or `WARN` (the planner must surface the conflict for human
review).

## How to use this index

Find the row that matches what you are about to change, open that one policy file, and read it before writing code. You do not need to load every policy — load the ones
your change touches. The root [`AGENTS.md`](../../AGENTS.md) "Reference Files" table routes here; this page routes to the individual policy files.

Terminology used throughout: [`glossary.md`](glossary.md).

Some policies bundle a full reference alongside their rules: [Structured Logging](./policies/structured-logging.md) carries the write-side logging contract and the
read-side diagnostic playbook. {{GEN:if `module-isolation.md` was written, extend the sentence above to name it as carrying the cross-module reach model and the
published-surface working list; drop the clause entirely if that policy was not written.}}

## Code style, structure, and language

| Policy                                                   | Summary                                                                                               | Severity |
|----------------------------------------------------------|-------------------------------------------------------------------------------------------------------|----------|
| [Code Style](./policies/code-style.md)                   | {{GEN:one-line summary of the code-style policy naming the project's formatter and its config file.}} | BLOCK    |
| [Static Analysis](./policies/static-analysis.md)         | `{{STATIC_ANALYSIS_TOOL}}` runs clean; fix findings at the root cause, never suppress them.           | BLOCK    |
| [Formatter Authority](./policies/formatter-authority.md) | CI owns formatting and style linting; agents never run `{{FORMAT_COMMAND}}`, `--check` included.      | BLOCK    |
| [Naming and Casing](./policies/naming-and-casing.md)     | {{GEN:one-line summary of the language's casing rules as fixed by this project.}}                     | BLOCK    |
| [Simplicity First](./policies/simplicity-first.md)       | Simplest implementation that works; no speculative abstraction, flags, or shims.                      | WARN     |
| [No Magic Values](./policies/no-magic-values.md)         | Domain values (status, type, role, channel) live in an enum or named constant, never inline.          | WARN     |
| [Strong Typing](./policies/strong-typing.md)             | Explicit declared types everywhere; no loosely-keyed maps as a data-transfer shape.                   | BLOCK    |

## Data, configuration, and transfer shapes

| Policy                                                       | Summary                                                                                      | Severity |
|--------------------------------------------------------------|----------------------------------------------------------------------------------------------|----------|
| [Data Transfer Objects](./policies/data-transfer-objects.md) | Typed transfer shapes at serialization boundaries; declarative field lists.                  | WARN     |
| [Configuration Access](./policies/configuration-access.md)   | Environment variables are read only at the configuration layer; app code reads typed config. | BLOCK    |
| [Typed Config Objects](./policies/typed-config-objects.md)   | Config objects load values into typed properties once, not per-read getters.                 | BLOCK    |

## Logging, errors, and validation

| Policy                                                 | Summary                                                                                               | Severity |
|--------------------------------------------------------|-------------------------------------------------------------------------------------------------------|----------|
| [Structured Logging](./policies/structured-logging.md) | Static message template plus typed context; no stdout debug output in committed code.                 | BLOCK    |
| [Error Handling](./policies/error-handling.md)         | Errors are for exceptional cases; catch narrowly, never swallow; expected outcomes are return values. | BLOCK    |
| [Input Validation](./policies/input-validation.md)     | Validate once at the boundary; internal callees assume validated input.                               | WARN     |

## Testing and documentation

| Policy                                                   | Summary                                                                                   | Severity |
|----------------------------------------------------------|-------------------------------------------------------------------------------------------|----------|
| [Testing](./policies/testing.md)                         | Every behavioral change ships {{TEST_FRAMEWORK}} coverage; assert intention, not wording. | BLOCK    |
| [Test Data Factories](./policies/test-data-factories.md) | Test data comes from the shared factory/builder surface, not bespoke per-file helpers.    | BLOCK    |
| [Test Helper Classes](./policies/test-helper-classes.md) | Shared test logic lives on named helper types, never as file-level globals.               | BLOCK    |
| [Documentation](./policies/documentation.md)             | Every change ships the doc and glossary updates that keep the standards accurate.         | BLOCK    |

## Project workflow

| Policy                                                     | Summary                                                                  | Severity |
|------------------------------------------------------------|--------------------------------------------------------------------------|----------|
| [Dependency Licensing](./policies/dependency-licensing.md) | Permissive licenses only. GPL/AGPL/SSPL are forbidden and halt the work. | BLOCK    |
| [Dependencies](./policies/dependencies.md)                 | A new third-party dependency is a justified decision, not a reflex.      | WARN     |
| [Version Control](./policies/version-control.md)           | Branch off `{{DEFAULT_BRANCH}}`; focused commits that message the *why*. | WARN     |

{{GEN:append one table section per additional policy group this project actually received. This covers every Tier 2 conditional policy that gated in — data access, schema
migrations, module isolation (its own section, "Modules and boundaries"), background jobs, concurrency guards, immutable value types, frontend component testing, type
sealing, authorization identifier naming — and every framework-pack policy that was copied in. No Tier 2 policy is pre-listed above, so each one that landed needs a row
written here. Each row follows the same shape: linked title, one-line summary, BLOCK/WARN severity matching that file's footer. Remove any row above whose policy file was
not written.}}
