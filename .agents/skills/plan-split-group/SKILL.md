---
name: plan-split-group
description: Split a single fleshed-out implementation plan into sequentially ordered sub-epic directories, each containing a self-contained plan.md file. Output is compatible with plan-review-group (which scans for **/plan.md). Extends plan-split — use when splitting an epic-level master plan into sub-epics that each warrant their own full implementation plan, rather than lightweight task files.
disable-model-invocation: true
argument-hint: [ path to the master plan file ]
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - Glob
  - Bash(ls *)
  - Bash(dirname *)
  - Bash(test -f *)
  - Bash(test -d *)
  - Bash(mkdir -p *)
model: opus
---

# Plan Split — Group Mode (extends plan-split)

This skill extends the base `plan-split` skill with group-mode output: instead of writing flat `##-slug.md` files, it
writes `##-slug/plan.md` sub-epic directories. The resulting `plan.md` files are full, self-contained implementation
plans — compatible with `plan-review-group`, which scans for `**/plan.md`.

## File Operation Rules

Read and follow `.agents/skills/file-operations/SKILL.md`.

**Before doing anything else**, read the base skill:

```
.agents/skills/plan-split/SKILL.md
```

Follow every guideline defined there for: resolving the plan file (Step 0), analyzing and decomposing the plan
(Step 1), and confirming the proposed split with the user (Step 2). The overrides below replace only Steps 3 and 4.

---

## Override: Step 3 — Write sub-epic plan files

Once the user approves the proposed split, write each sub-epic as a **directory containing a `plan.md` file**.

**Directory name:** `<sequence>-<slug>/`
**File:** `plan.md` inside that directory
**Location:** alongside the master plan file (same directory)

Before writing, create each output directory using `Bash(mkdir -p *)`.

---

### Sub-epic plan.md format

Each `plan.md` must be a complete, standalone implementation plan. Do not use the simplified format from the base
`plan-split` skill (Dependencies / Context / Steps / Acceptance Criteria). Use the full plan format below.

```markdown
# <Title> — Implementation Plan

> **Parent plan:** `<relative path from this file to the master plan, e.g. ../plan.md>`
> **Sub-epic NN of TT.** <One sentence stating what this sub-epic depends on and/or what it unblocks.
> Use "No dependencies." if none. Use "Depends on: `<##-slug>`." if blocked.>
> <Optional: one-line migration note if this epic includes a schema migration, e.g. "Migration: AddFooBar (#N of M).">
>
> **<Reproduce any project-wide constraint callout from the master plan verbatim, e.g. breaking-change policy,
> pre-production status, or release constraints. Omit if the master plan has none.>**

## Goal

<One to three paragraphs. State what this sub-epic produces, what problem it solves, and what "done" looks like.
Include a concrete success condition: what passes, what compiles, or what a user can observe when this is complete.>

## Out of scope

<Bullet list of work that is explicitly NOT part of this sub-epic, with a pointer to which sub-epic owns it.
Format: `- <Thing> — <##-slug> or "future plan".`
Omit this section only if there is genuinely nothing to call out.>

## Affected components

| Component / Module | Change | Summary |
|--------------------|--------|---------|
| `<path or name>`   | New / Modified / Deleted | <One-line description of what changes and why.> |

## Architecture

<Detailed technical content extracted from the master plan for this sub-epic's scope. Include:

- Namespace and file layout (use fenced code blocks for directory trees)
- Interface and type definitions (use fenced code blocks with the exact signatures)
- Key design decisions and constraints
- Shared conventions that an implementing agent must follow

Reproduce this content verbatim or lightly edited from the master plan. Do not summarize or lose detail.
If the master plan has no architecture section for this sub-epic's work, derive it from the implementation steps.>

## Implementation steps

<The ordered implementation steps from the master plan that belong to this sub-epic. Copy verbatim or
lightly edited so each step stands alone. Each step must be actionable by a coding agent without referring
back to the master plan or any sibling sub-epic.

If a step from the master plan spans multiple sub-epics, split the step text so each sub-epic contains only
its portion.

Shared context (schema decisions, API contracts, naming conventions) that other sub-epics also need must be
reproduced here — do not say "see sub-epic 01 for details".>

## Configuration

<New config keys, environment variables, appsettings entries, or feature flags introduced by this sub-epic.
Include the key name, type, default value, and what it controls. Omit this section if this sub-epic
introduces no new configuration.>

## Migration

<Database migration details: migration name, tables/columns added or modified, index changes, and any
data-backfill requirements. Omit this section if this sub-epic requires no schema changes.>

## Tests

<Test plan table listing every test class or test scenario this sub-epic must deliver.>

| Test | Type | Scenarios |
|------|------|-----------|
| `<TestClassName>` | Unit / Feature / Integration | <What it covers> |

## Documentation updates

<List every documentation file that must be created or updated as part of this sub-epic, and what
each update must include. Omit this section if no documentation changes are required.>
```

---

### Content rules (in addition to base plan-split rules)

- **Intro blockquote is mandatory.** Every `plan.md` must open with the `>` callout block containing the parent
  plan path, sub-epic numbering (`NN of TT`), and the dependency statement. Reproduce any project-wide constraint
  callout from the master plan verbatim inside this block.
- **Parent plan path is relative.** Compute it from the sub-epic directory to the master plan file, e.g., if the
  master plan is at `docs/_planning/my-epic/plan.md` and the sub-epic is at `docs/_planning/my-epic/01-slug/plan.md`,
  the relative path is `../plan.md`.
- **Sub-epic numbering.** Use `NN of TT` where `NN` is the zero-padded sequence number and `TT` is the total count
  of sub-epics in the split.
- **Out of scope is cross-referenced.** Each "out of scope" bullet must name the sub-epic slug that owns the
  excluded work (or "future plan" if it is out of scope for the entire split).
- **Omit empty sections.** If a sub-epic has no configuration changes, no migration, or no documentation updates,
  omit the corresponding section entirely rather than leaving a placeholder.
- **Architecture before steps.** The Architecture section must appear before Implementation steps. If the master
  plan interleaves architecture detail inside numbered steps, extract the architectural declarations into the
  Architecture section and leave only procedural instructions in Implementation steps.

Write all sub-epic directories and `plan.md` files before proceeding to Step 4.

---

## Override: Step 4 — Final summary

After all files are written, output:

```
## Plan split complete

**Source:** <source plan path>
**Directory:** <plan file directory>
**Sub-epics written:** N

| # | Directory | Title | Blocked by | Blocks |
|---|-----------|-------|------------|--------|
| 01 | 01-slug/plan.md | … | — | 02 |
…
```

Then ask:

> All sub-epic plans have been written to `<plan file directory>`. Would you like me to run `/plan-review-group`
> on the output directory to review and enrich them as a group?

---

**Task:** $ARGUMENTS
