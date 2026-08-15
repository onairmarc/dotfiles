# Plan and Sub-plan Format

The canonical structure of the artifacts the planning pipeline produces and consumes:

- **`feature-planning`** emits a **master plan** (`plan.md`) per the *Master plan structure* below.
- **`plan-split`** decomposes a master plan into **sub-plan files** per the *Sub-plan structure* below, carrying the *Dependency
  contract*.
- **`plan-execute`** parses those sub-plans per the *Dependency contract* and runs them.

These are the load-bearing cross-skill assumptions. A change to any of them must be made here, in one place, and honored by every skill
above — an edit to the sub-plan Dependency contract that only lands in `plan-split` silently breaks `plan-execute`'s parser.

The `## Delivery constraints` block below is **reproduced verbatim into every emitted plan and sub-plan** so the implementing agent is
bound by it from the plan alone. It is the one block emitters copy; keep the three constraints identical across both templates.

---

## The Delivery constraints block (reproduce verbatim in plan.md and every sub-plan)

```markdown
## Delivery constraints

Reproduce these verbatim — they bind the implementing agent:

- **Vertical slice.** This unit of work cuts through every layer it touches — schema, domain, service, transport, UI — and ends with that
  behavior wired up and observable. Nothing is left registered, injected, or created but uncalled, and wiring is never deferred to a later
  unit.
- **In place, on the current branch — unless it is main.** Before the first change, run `git rev-parse --abbrev-ref HEAD` to read the
  branch actually checked out; never assume from memory or from this document. If it is not the repository's main branch, work in place on
  it. If it is main, run `git checkout -b <descriptive-branch-name>` first and work on that new branch. Either way, do not switch to an
  existing branch, merge, or use a git worktree.
- **Repository-native verification.** Use the project's own test framework and runner command (substitute the real one, e.g.
  `vendor/bin/pest --parallel`) with its existing test directories, base classes, and factories. Do not write throwaway driver scripts,
  scratch runners, sandbox projects, or bespoke assertion helpers.
```

Fill in the real runner command, discovered from the plan or the repository — never leave it as a placeholder, and never replace this
block with a pointer to `delivery-constraints/SKILL.md`; the artifact must bind the agent on its own.

---

## Master plan structure (`feature-planning`)

Written to `$PLAN_DIR/<kebab-case-feature-name>/plan.md` (create the directory if needed).

```markdown
# <Feature Name> — Implementation Plan

## Goal

One paragraph: what problem this solves and what success looks like.

## Out of scope

Explicit list of things this plan does NOT cover. If nothing is out of scope, say so.

## Affected components

Table: Component / Module | Change type (New / Modified / Deleted) | Summary of change

## Delivery constraints

<Reproduce the Delivery constraints block above verbatim, with the project's real runner command filled in.>

## Architecture

### <Sub-section per significant design decision>

Describe the design. For cross-boundary changes, include the message/event/API flow. Name the concrete classes, interfaces, files, and
methods involved. If a new package or service is created, list its directory structure. When a decision here is cross-cutting or
architectural — an approach chosen over real alternatives, a boundary drawn, a trade-off accepted — list an ADR for it under
**Documentation updates** so the reasoning survives the plan's deletion.

## Implementation steps

Organized as **vertical slices**. Group the steps under one `### Slice N — <behavior delivered>` heading per slice, ordered so each slice
ships working behavior. Under each slice heading, state in one line what is observable when the slice is done, then give the ordered steps.

If shared groundwork genuinely cannot live inside the first slice (e.g. a migration three slices read), it may lead as
`### Slice 0 — <groundwork>` with an explicit sentence explaining why it cannot be co-located with Slice 1.

Each step must be:

- Specific enough that an agent can execute it without asking questions
- Scoped to one logical unit of work (one class, one migration, one endpoint)
- Explicit about file paths

The **final step** of every plan must delete this plan directory, because plans are throwaway scaffolding (see `## Plan lifecycle`).
State it explicitly, e.g.: "Delete the `<$PLAN_DIR>/<feature>/` plan directory — the feature is implemented and its durable docs now live
in their real home; the plan must not be committed as a lingering artifact."

## Configuration

List every new config key. For each: key name and location; type and valid range; default value; whether it is hot-reloadable (if
applicable); why it needs to be configurable (if not obvious). If there is no new configuration, say so explicitly.

## Migration

If a database migration is required: list the new/changed tables and columns; note any data backfill logic; confirm the migration is
included in the implementation steps. If no migration is required, say so explicitly.

## Tests

Name the project's test framework and the exact runner command up front. Every test below uses that tooling and lives in the project's
existing test directories — no bespoke harness, scratch script, or standalone sandbox. For each slice: what is being tested (unit,
integration, or end-to-end); which test project or directory, and which existing base class / factory / fixture it builds on; key
scenarios (happy path + at least one failure/edge case per logical unit); the runner command that must pass before the next slice starts.
If the repository has no test tooling, say so explicitly and state how each slice is verified with what does exist instead.

## Documentation updates

List every doc that must be updated:

- CLAUDE.md / AGENTS.md (if architecture, project structure, or policies change)
- Developer docs (if implementation details change)
- User-facing docs (if user-facing behavior changes)
- Package or module READMEs (for new or significantly changed components)
- An **ADR** (Architecture Decision Record), when this plan settles a cross-cutting or architectural decision worth preserving — an
  approach chosen over alternatives, a boundary drawn, a trade-off accepted. Record it as a durable, numbered document at
  `docs/decisions/NNNN-<slug>.md` (or the owning module's `docs/decisions/` when the decision is module-scoped), capturing the question,
  the options weighed, the decision, and its consequences. The plan is deleted; the ADR is the surviving record of *why* the code looks
  the way it does. If the project documents its own ADR convention (Documentation policy / glossary), follow it.

Durable docs land in their real home (standards, root README/AGENTS, glossary, an ADR under `docs/decisions/`, or the module's own
AGENTS/README). Never point shipped docs or code at this plan file — the plan is deleted once implemented.

## Plan lifecycle

This plan is **throwaway scaffolding**, not durable documentation. Once the implementation and its durable docs land, the entire
`<$PLAN_DIR>/<feature>/` directory (this `plan.md` and any split sub-plans) is deleted in the same change — a missing or staged-deleted
plan directory at commit time is intentional and must not be restored. The final implementation step above performs that deletion. If the
repository documents its own planning lifecycle (e.g. `docs/_planning/README.md`), that document governs.
```

---

## Sub-plan structure (`plan-split`)

**Filename:** `<sequence>-<slug>.md`, where `sequence` is a two-digit zero-padded number (01, 02, …) reflecting execution order and `slug`
is a short imperative kebab-case name (`create-user-model`). **Location:** the same directory as the source `plan.md`, written alongside
it.

```markdown
# <Title>

## Dependencies

**Blocked by:** <comma-separated list of plan filenames, or "none">
**Blocks:** <comma-separated list of plan filenames, or "none">

---

## Context

<One paragraph: why this unit of work exists, what it produces, how it fits the overall feature. Include any constraints or decisions from
the master plan relevant to this sub-plan only. State in one line what behavior is observable once this slice is complete. If this is a
shared-groundwork sub-plan, state why the groundwork could not live inside the first behavioral slice.>

---

## Delivery constraints

<Reproduce the Delivery constraints block above verbatim, with the project's real runner command filled in. Mandatory in every sub-plan.>

---

## Steps

<The ordered implementation steps from the master plan that belong to this sub-plan. Keep them verbatim or lightly edited to stand alone —
do not summarize or lose detail. Each step actionable without referring back to the master plan.>

---

## Acceptance Criteria

<The acceptance criteria from the master plan that apply to this sub-plan's deliverable. Reproduce only the subset this sub-plan is
responsible for. Never omit acceptance criteria; if the master plan has none, derive them from the steps.>
```

### Content-extraction rules

- Copy relevant steps **verbatim** from the master plan — do not paraphrase or shorten implementation detail.
- If a master-plan step spans multiple sub-plans, split the step text so each sub-plan contains only its portion.
- Every sub-plan is **self-contained**: an agent reading only that file and the codebase can implement it without any other sub-plan or the
  master plan. Reproduce shared context (schema decisions, API contracts, naming conventions) in every sub-plan that needs it — never "see
  plan 01 for details".
- **Project standards & policies carry into every sub-plan.** Reproduce the subset of `$PROJECT_STANDARDS` (see [`paths.md`](paths.md))
  that applies to each sub-plan's work in that sub-plan's Context — do not point back to the master plan.

---

## Dependency contract (`plan-split` emits ⇄ `plan-execute` parses)

This is the exact, machine-readable contract binding the two skills. Both sides must agree byte-for-byte.

- **Files.** Sub-plans are `<sequence>-<slug>.md` written as siblings of the master `plan.md`. `plan-execute` lists `*.md` in the
  directory and **excludes `plan.md`** — that is the master plan, never a sub-plan, and is never read or executed.
- **Dependency header.** Each sub-plan carries a `## Dependencies` section with two lines: `**Blocked by:**` and `**Blocks:**`, each a
  comma-separated list of sub-plan **filenames** or the literal `none`.
- **Mirror invariant.** `blocked_by` and `blocks` are mirror images: if `02` is blocked by `01`, then `01` must list `02` in its `blocks`.
  Plans with no dependencies get `none` for both. Do not invent dependencies the master plan does not imply.
- **Identity fields `plan-execute` reads per file:** `file` (filename), `sequence` (the numeric prefix), `title` (the H1 heading),
  `blocked_by`, `blocks`, and the full file content (passed verbatim to the sub-agent).
- **Ordering.** `plan-execute` topologically sorts the graph and runs sub-plans **one at a time** in `sequence` (numeric-prefix) order —
  never concurrently. A cycle is a hard error. Two sub-plans that both depend only on `01` still get distinct sequence numbers and run
  back-to-back, never simultaneously.

"Parallel" never refers to agents. The only sanctioned parallelism is inside the test runner itself (`vendor/bin/pest --parallel`,
`phpunit --parallel`, Jest workers).
