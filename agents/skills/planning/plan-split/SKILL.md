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
---

# Plan Split

You are a technical architect decomposing a large implementation plan into discrete, sequentially ordered sub-plans that can each be handed to an agent as a
self-contained unit of work.

## File Operation Rules

Read and follow `~/.config/opencode/skills/file-operations/SKILL.md`.

## Delivery Constraints

Read and follow `~/.config/opencode/skills/delivery-constraints/SKILL.md`. Two consequences govern this skill:

- **Every sub-plan is a vertical slice.** Split boundaries are cut by behavior, never by layer. A sub-plan that delivers "the models", "the interfaces", or "the API
  surface" with its callers deferred to a later sub-plan is an invalid split — re-cut it.
- **Every sub-plan inherits the branch and testing rules.** All sub-plans land in place on the currently checked-out branch — or, when a branch check shows main is
  checked out, on a new branch created off main by the first sub-plan to run — and each verifies itself with the repository's own test tooling. Reproduce both rules in
  every sub-plan (see Step 3).

---

## Step 0 — Resolve the plan file

If `$ARGUMENTS` contains a file path, use it as the source plan file.

Otherwise, use `AskUserQuestion` to ask the user:

> **Which plan file should I split?**
> Please provide the path to the master plan file (e.g. `docs/plans/feature.md`).

Once you have a path:

- Read the file with `Read`. If it does not exist, stop with an error.
- Derive the **output directory** as the directory that contains the plan file (i.e. `dirname` of the resolved path). The sub-plan files will be written alongside the
  source plan in this same directory.

No separate output directory argument is accepted or needed.

---

## Step 1 — Analyze and decompose the plan

Read the plan in full. Identify the natural units of work that can be split into separate sub-plans.

### What makes a good split boundary

A good sub-plan boundary is where:

- **A vertical slice of behavior is complete** — the sub-plan cuts through every layer it touches (schema, domain, service, transport, UI) for one narrow piece of
  behavior, and leaves it wired up and observable. This is the primary criterion; a boundary that fails it is wrong even if it satisfies every other bullet.
- A distinct deliverable is produced (a file, a service, a migration, a tested feature)
- There is a natural handoff — the next phase can only begin once this one is complete
- The deliverable leaves the codebase in a state where the relevant test suite can run and pass, providing a verification checkpoint before the next sub-plan begins
- Each sub-plan can be implemented end-to-end by a single coding agent in one sitting without needing context from a sibling sub-plan that has not yet run

Sub-plans are executed strictly one at a time by `plan-execute` — never concurrently. Always favor **accuracy of implementation over speed of implementation**. When in
doubt, split finer rather than coarser: more, smaller phases let the test suite run between them and catch regressions before later phases compound them.

A natural test gate between phases is one of the strongest signals that a split boundary is correct. If a candidate sub-plan ends in a state where tests cannot
meaningfully run (e.g. it leaves the codebase mid-refactor or half-migrated), either move the boundary or merge it with the next sub-plan so the seam falls on a testable
state.

**"Parallel" never refers to agents.** The only parallelism allowed is inside the test runner itself (e.g. `vendor/bin/pest --parallel`, `phpunit --parallel`, Jest
workers). Coding sub-agents always run one at a time.

### What NOT to split

- **Never split by layer.** "All models" → "all repositories" → "all controllers" → "wire it up" is a horizontal decomposition and is forbidden. When a slice is too big
  for one sub-plan, cut it by taking a smaller piece of behavior all the way through the stack (one endpoint instead of five, one field instead of the whole form), never
  by removing a layer and deferring it.
- Steps so small they add more overhead than value (e.g. a single line config change does not deserve its own plan)
- Steps that are inseparable because they form a single atomic transaction (e.g. a migration + its seeder that must run together)
- Work that only makes sense when implemented together (splitting just to have more sub-plans adds noise without benefit when execution is sequential)

**Shared groundwork exception:** groundwork that several slices depend on and that genuinely cannot be co-located with the first slice (e.g. a migration three slices
read, or a package install) may become sub-plan `01`. Keep it as small as possible and state in that sub-plan's Context why it could not live inside the first behavioral
slice. Anything that *can* live inside the first slice must.

**Change-audit as final sub-plan:** the last sub-plan before plan-directory cleanup must be a change-audit pass. This sub-plan invokes the `change-audit` skill
(`~/.config/opencode/skills/audits/change-audit/SKILL.md`) to audit every file changed on the branch for materially useful simplifications and implement accepted fixes. It is
blocked by all preceding sub-plans and blocks nothing (except the plan-deletion step, which is not a sub-plan). Its steps are: run `/change-audit`, confirm all tests
pass after fixes are applied. If the master plan already contains a change-audit step, extract it into this final sub-plan; if it does not, add one.

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

Once the user approves, write each sub-plan following the **Sub-plan structure**, **Content-extraction rules**, and **Dependency contract** in
`~/.config/opencode/skills/planning-commons/plan-format.md`. In brief: filename `<sequence>-<slug>.md` written alongside the source plan; a `## Dependencies` header with
mirror-image
`**Blocked by:**` / `**Blocks:**` filename lists; the `## Delivery constraints` block reproduced verbatim with the project's real runner command filled in (mandatory,
never a pointer); every sub-plan self-contained, with steps copied verbatim from the master plan and the applicable subset of `$PROJECT_STANDARDS` carried into each
sub-plan's Context. Write all files before proceeding to Step 4.

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

- **Slice vertically, always.** Every sub-plan ships working behavior across the stack. If a proposed sub-plan cannot be described in terms of what someone can now do or
  observe, it is a layer, not a slice — re-cut it.
- **Preserve detail.** The master plan has been carefully written — do not lose implementation specifics when extracting into sub-plans.
- **Prefer more context over less.** If in doubt whether a piece of context belongs in a sub-plan, include it.
- **Favor accuracy over speed.** When choosing between fewer larger sub-plans or more smaller ones, pick the decomposition that maximizes correctness — typically more,
  smaller phases with test gates between them.
- **Require a testable seam between phases.** Each sub-plan should leave the codebase in a state where the test suite can run. Acceptance criteria should describe what
  `vendor/bin/pest --parallel` (or the project's equivalent) is expected to show when the sub-plan is complete.
- **Sequence reflects dependency and execution order.** Sub-plans run one at a time in dependency-respecting order; pick sequence numbers that reflect the order an agent
  should implement them in. Two sub-plans that both depend only on 01 still get distinct sequence numbers (e.g. 02 and 03) and run back-to-back, never simultaneously.
- **Slug naming:** use imperative verb phrases — `create-user-model`, `add-queue-worker`, `write-feature-tests`.
- **Never omit acceptance criteria** from a sub-plan. If the master plan has none, derive them from the steps.

---

**Task:** $ARGUMENTS