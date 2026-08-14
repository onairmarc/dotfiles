# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

> **Before interacting with any plan file or executing any plan**, read
> [`{{PLANNING_PATH}}/README.md`]({{PLANNING_PATH}}/README.md). It defines the plan lifecycle — plans are throwaway
> scaffolding, durable docs land elsewhere, the plan index is kept in lockstep, and a plan's
> `{{PLANNING_PATH}}/<feature>/` directory is deleted in the same change that implements it.

## Reference Files

When working in a given area, read the corresponding standards doc before making changes. When working in a domain area, read the corresponding skill file for key files,
hub methods, and invariants before making changes.

> **Skills exist at two levels.** Repo-level skills live in `.agents/skills/` and are listed in the table below.
> User-level skills live in `~/.claude/skills/` (i.e., `C:\Users\<username>\.claude\skills\` on Windows or
> `~/.claude/skills/` on Linux/macOS) and are **not** listed here. Before concluding a skill does not exist, check the
> user-level skills directory. User-level skills take the same `/<skill-name>` invocation form as repo skills.

> **Memory writes MUST mirror into a repo skill.** Whenever an AI agent records something to its machine-local memory
> (e.g. the per-user `memory/` store), it **MUST** also persist that same knowledge into the corresponding skill under
> [`.agents/skills/`](.agents/skills). Find the skill whose domain the fact belongs to (use the Reference Files table
> below) and update its `SKILL.md` (or a `resources/` file). If the fact does not map to any existing skill, **create a
> new repo-level skill** for it and add a row to the table. Machine-local memory is a per-developer convenience cache
> only — it is never the source of truth. Everything an agent needs to work in this repo must be self-contained in the
> repo (skills, docs, code), not local to any one developer's machine. Do not leave a memory entry that has no
> repo-side counterpart.
>
> **Prefer skill reference files to manage context.** Skills are the primary way to load only the context a task needs
> — read the relevant `SKILL.md` (and its `resources/` files) instead of scanning the whole repo. To make this work,
> every `SKILL.md` **MUST** maintain an accurate index of the in-repo files and invariants for its domain, with a pointer to each. **Keep that index current as part of
> every memory sync**: when you mirror a memory into a skill, also verify and correct the skill's file index (paths, symbol names, added/removed/renamed files) so
> the agent can always locate the right in-repo file from the skill alone. A stale index is a bug — fix it in the same edit.

| Working on...                              | Read                                                                                           |
|--------------------------------------------|------------------------------------------------------------------------------------------------|
| Coding standards — the policy index        | [`{{DOCS_PATH}}/policies.md`]({{DOCS_PATH}}/policies.md)                                       |
| Logging — what to emit, and how to read it | [`{{DOCS_PATH}}/policies/structured-logging.md`]({{DOCS_PATH}}/policies/structured-logging.md) |
| Project terminology and acronyms           | [`{{DOCS_PATH}}/glossary.md`]({{DOCS_PATH}}/glossary.md)                                       |

{{GEN:add a row for `module-isolation.md` ("Cross-module reach, published surface") only if that Tier 2 policy was actually written. Then add one row per repo-level skill
found under the project's skills directory — the note above promises this table lists them, so an existing skill that is missing here makes that promise false; give each
row the domain it covers and a link to its `SKILL.md`. Then add a row for any other area-specific doc this project has. Do NOT list a doc or skill that does not exist. If
the project has no skills directory, add no skill rows.}}

## Project Overview

{{PROJECT_NAME}} — {{PROJECT_TAGLINE}}

{{GEN:a short paragraph describing what the system is, its primary language ({{PRIMARY_LANGUAGE}}) and stack ({{STACK}}), and how the code is organized
({{MODULE_LAYOUT}}). Author from detection and confirm with the user.}}

## Key Commands

| Task                     | Command                         | Agent may run it?                                   |
|--------------------------|---------------------------------|-----------------------------------------------------|
| Build                    | `{{BUILD_COMMAND}}`             | **Yes — part of the gate**                          |
| Test                     | `{{TEST_COMMAND}}`              | **Yes — part of the gate**                          |
| Static analysis          | `{{STATIC_ANALYSIS_COMMAND}}`   | **Yes — part of the gate**                          |
| Format / style lint      | `{{FORMAT_COMMAND}}`            | **No — CI owns this, in every mode. Never run it.** |

> **Your gate is: it builds, the tests pass, and `{{STATIC_ANALYSIS_TOOL}}` is clean.** Those three, and nothing else.
>
> **Never run `{{FORMAT_COMMAND}}`** — nor any other formatter, style linter, import sorter, or codemod, not even in `--check`/`--dry-run` mode. CI owns style end to end.
> A style linter rewrites its own findings automatically, so its output is a list you must not act on: reading it just burns turns hand-matching whitespace the tool was
> going to fix for free. Write the code plainly and leave style alone.
>
> `{{STATIC_ANALYSIS_COMMAND}}` is different and is **required** — it reports real defects (type errors, null dereferences, impossible branches) that only you can fix.
> See [`{{DOCS_PATH}}/policies/formatter-authority.md`]({{DOCS_PATH}}/policies/formatter-authority.md) and
> [`{{DOCS_PATH}}/policies/static-analysis.md`]({{DOCS_PATH}}/policies/static-analysis.md).

{{GEN:add rows for any other commands an agent needs regularly — run locally, apply migrations, codegen — detected from scripts/CI. Omit the extra rows if there are
none.}}

## Policies

Coding standards live one policy per file under [`{{DOCS_PATH}}/policies/`]({{DOCS_PATH}}/policies/), routed by the index at [
`{{DOCS_PATH}}/policies.md`]({{DOCS_PATH}}/policies.md). Open the index, find the row matching what you are about to change, and read that one policy file — you do not
need to load the whole rule set. Each policy is tagged **BLOCK** (a plan that violates it must not proceed without an explicit override) or **WARN** (surface the conflict
for human review).

The load-bearing rules an agent must not violate:

- **`{{STATIC_ANALYSIS_TOOL}}` and the test suite must pass before any change is considered done.** Never suppress a finding, skip a test, or label a failure
  "pre-existing" — fix the root cause.
- **Never run `{{FORMAT_COMMAND}}` or any other formatter/style linter/codemod, in any mode including `--check`.** CI owns style — see
  [`{{DOCS_PATH}}/policies/formatter-authority.md`]({{DOCS_PATH}}/policies/formatter-authority.md). This does not apply to
  `{{STATIC_ANALYSIS_COMMAND}}`, which you are required to run.
- **Structured logging only** via {{LOG_LIBRARY}}; no `print`/stdout logging in committed code.
- **Never add a GPL, AGPL, or SSPL dependency**, at any depth of the tree. Discovering one halts the work until it is replaced with a permissively licensed package or
  reimplemented here — see [`{{DOCS_PATH}}/policies/dependency-licensing.md`]({{DOCS_PATH}}/policies/dependency-licensing.md).

{{GEN:if `module-isolation.md` was written, add the bullet "**Every cross-module read and write goes through a service method on the owning module** — never query or
mutate another module's models directly, even for a single call site" linking to it. Then add one bullet for each other BLOCK-severity policy that was written whose rule
an agent could plausibly violate without noticing — especially the project-specific policies authored during the interview. Link each bullet to its policy file under
{{DOCS_PATH}}/policies/. Omit any that are already covered above.}}
