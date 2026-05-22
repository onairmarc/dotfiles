---
name: plan-split
description: Split a single fleshed-out implementation plan into sequentially ordered sub-plan files written alongside it in the same directory, with dependency (blockers/blocks) headers on each sub-plan. Sub-plans are always executed one at a time by plan-execute, so splits should optimize for clean sequential handoff, not concurrency. Invoke when asked to break a plan into phases or stages.
disable-model-invocation: true
argument-hint: [ path to the source plan file ]
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - Glob
  - Bash(ls *)
  - Bash(dirname *)
  - Bash(test -f *)
model: opus
---

# Plan Split

You are a technical architect decomposing a large implementation plan into discrete, sequentially ordered sub-plans
that can each be handed to an agent as a self-contained unit of work.

## File Operation Rules

Read and follow `.agents/skills/file-operations/SKILL.md`.

---

## Step 0 — Resolve the plan file

If `$ARGUMENTS` contains a file path, use it as the source plan file.

Otherwise, use `AskUserQuestion` to ask the user:

> **Which plan file should I split?**
> Please provide the path to the master plan file (e.g. `docs/plans/feature.md`).

Once you have a path:

- Read the file with `Read`. If it does not exist, stop with an error.
- Derive the **output directory** as the directory that contains the plan file (i.e. `dirname` of the resolved path).
  The sub-plan files will be written alongside the source plan in this same directory.

No separate output directory argument is accepted or needed.

---

## Step 1 — Analyze and decompose the plan

Read the plan in full. Identify the natural units of work that can be split into separate sub-plans.

### What makes a good split boundary

A good sub-plan boundary is where:

- A distinct deliverable is produced (a file, a service, a migration, a tested feature)
- There is a natural handoff — the next phase can only begin once this one is complete
- The deliverable leaves the codebase in a state where the relevant test suite can run and pass, providing a
  verification checkpoint before the next sub-plan begins
- Each sub-plan can be implemented end-to-end by a single coding agent in one sitting without needing context from a
  sibling sub-plan that has not yet run

Sub-plans are executed strictly one at a time by `plan-execute` — never concurrently. Always favor **accuracy of
implementation over speed of implementation**. When in doubt, split finer rather than coarser: more, smaller phases
let the test suite run between them and catch regressions before later phases compound them.

A natural test gate between phases is one of the strongest signals that a split boundary is correct. If a candidate
sub-plan ends in a state where tests cannot meaningfully run (e.g. it leaves the codebase mid-refactor or
half-migrated), either move the boundary or merge it with the next sub-plan so the seam falls on a testable state.

**"Parallel" never refers to agents.** The only parallelism allowed is inside the test runner itself
(e.g. `vendor/bin/pest --parallel`, `phpunit --parallel`, Jest workers). Coding sub-agents always run one at a time.

### What NOT to split

- Steps so small they add more overhead than value (e.g. a single line config change does not deserve its own plan)
- Steps that are inseparable because they form a single atomic transaction (e.g. a migration + its seeder that must
  run together)
- Work that only makes sense when implemented together (splitting just to have more sub-plans adds noise without
  benefit when execution is sequential)

### Producing the split

For each sub-plan, determine:

| Field        | Meaning                                                                                          |
|--------------|--------------------------------------------------------------------------------------------------|
| `sequence`   | Two-digit zero-padded number (01, 02, …) reflecting execution order                              |
| `slug`       | Short kebab-case name describing the deliverable (e.g. `create-user-model`)                      |
| `title`      | Human-readable title                                                                             |
| `blocked_by` | List of sequence numbers that must be complete before this plan can start                        |
| `blocks`     | List of sequence numbers that cannot start until this plan is complete                           |
| `content`    | The subset of the master plan's steps, context, and acceptance criteria that belong to this unit |

**Dependency rules:**

- `blocked_by` and `blocks` must be mirror images: if plan 02 is blocked by 01, then 01 must list 02 in its `blocks`.
- Sequential plans (A must finish before B) must express this via `blocked_by`/`blocks`.
- Plans with no dependencies get empty lists for both fields.
- Do not invent dependencies that are not implied by the plan.

---

## Step 2 — Confirm the proposed split with the user

Before writing any files, present the proposed split to the user via `AskUserQuestion`:

---

**Proposed split — N sub-plans**

| #  | File         | Title | Blocked by | Blocks |
|----|--------------|-------|------------|--------|
| 01 | `01-slug.md` | Title | —          | 02, 03 |
| 02 | `02-slug.md` | Title | 01         | 04     |
| …  | …            | …     | …          | …      |

> Does this split look right? Reply with:
> - **Yes** to proceed
> - Any corrections (e.g. "merge 03 and 04", "02 should also be blocked by 01", "rename 03 to setup-queue")

Apply any corrections and re-present if changes were requested. Repeat until the user approves.

---

## Step 3 — Write the sub-plan files

Once the user approves, write each sub-plan file using the following format.

**Filename:** `<sequence>-<slug>.md`
**Location:** the same directory as the source plan file

### Sub-plan file format

```markdown
# <Title>

## Dependencies

**Blocked by:** <comma-separated list of plan filenames, or "none">
**Blocks:** <comma-separated list of plan filenames, or "none">

---

## Context

<One paragraph explaining why this unit of work exists, what it produces, and how it fits into the overall feature.
Include any constraints or decisions from the master plan that are relevant to this sub-plan only.>

---

## Steps

<The ordered implementation steps from the master plan that belong to this sub-plan. Keep them verbatim or
lightly edited to stand alone — do not summarize or lose detail. Each step should be actionable by a coding agent
without referring back to the master plan.>

---

## Acceptance Criteria

<The acceptance criteria from the master plan that apply to this sub-plan's deliverable. If the master plan has
global criteria, reproduce only the subset that this sub-plan is responsible for.>
```

**Rules for content extraction:**

- Copy relevant steps verbatim from the master plan. Do not paraphrase or shorten implementation detail.
- If a step from the master plan spans multiple sub-plans (e.g. "create X and wire it into Y" where X is plan 02 and
  wiring is plan 03), split the step text accordingly so each sub-plan contains only its portion.
- Every sub-plan must be self-contained: an agent reading only that file and the codebase should be able to implement
  it without referring to any other sub-plan or the master plan.
- Shared context (e.g. database schema decisions, API contracts, naming conventions) must be reproduced in every
  sub-plan that needs it — do not say "see plan 01 for details".

Write all files before proceeding to Step 4.

---

## Step 4 — Final summary

After all files are written, output:

```
## Plan split complete

**Source:** <source plan path>
**Directory:** <plan file directory>
**Sub-plans written:** N

| # | File | Title | Blocked by | Blocks |
|---|------|-------|------------|--------|
| 01 | 01-slug.md | … | — | 02 |
…
```

Then ask:

> All sub-plans have been written to `<plan file directory>`. Would you like me to do anything else, such as running
> `/plan-review` on each sub-plan?

---

## Guidelines

- **Preserve detail.** The master plan has been carefully written — do not lose implementation specifics when
  extracting into sub-plans.
- **Prefer more context over less.** If in doubt whether a piece of context belongs in a sub-plan, include it.
- **Favor accuracy over speed.** When choosing between fewer larger sub-plans or more smaller ones, pick the
  decomposition that maximizes correctness — typically more, smaller phases with test gates between them.
- **Require a testable seam between phases.** Each sub-plan should leave the codebase in a state where the test suite
  can run. Acceptance criteria should describe what `vendor/bin/pest --parallel` (or the project's equivalent) is
  expected to show when the sub-plan is complete.
- **Sequence reflects dependency and execution order.** Sub-plans run one at a time in dependency-respecting order;
  pick sequence numbers that reflect the order an agent should implement them in. Two sub-plans that both depend only
  on 01 still get distinct sequence numbers (e.g. 02 and 03) and run back-to-back, never simultaneously.
- **Slug naming:** use imperative verb phrases — `create-user-model`, `add-queue-worker`, `write-feature-tests`.
- **Never omit acceptance criteria** from a sub-plan. If the master plan has none, derive them from the steps.

---

**Task:** $ARGUMENTS