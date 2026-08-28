# Parallel execution

Read this file only after the user selected **Yes** at the parallel-execution question. Sequential remains the default; this file is the exception.

This file is the single source of truth for the parallel branch of `plan-split` and `plan-execute`. Each skill applies the section named for it. Everything in that
skill's `SKILL.md` still applies except the sequential-only rules that section names.

---

## Shared

`blocked_by` / `blocks` **are** the execution graph. Sequence numbers stay unique identifiers; they do not serialize independent nodes.

These sequential contracts do **not** apply this run:

- The **Ordering** bullet in [`plan-format.md`](plan-format.md) ("one at a time… never concurrently")
- The delivery-constraints line "the only sanctioned parallelism is inside the test runner, never across agents"

Every coding agent still works in place on the same checked-out branch in the main working tree. Do not create a git worktree, and do not launch agents with
`isolation: "worktree"`.

Accuracy still beats speed. When independence is unclear, keep a blocker.

---

## plan-split

Overrides the sequential-only analysis rules in `plan-split` `SKILL.md` (one-at-a-time execution, "parallel never refers to agents", serializing independent slices, and
"splitting just to have more sub-plans adds noise"). Vertical slices, shared-groundwork exception, change-audit as the last sub-plan, file format, dependency-header
shape, and the confirm/write/summary steps still apply.

### How to cut the split

Do not add a blocker just to force a total order.

Two sub-plans are **independent** (no edge between them) only when all of these hold:

- Neither's deliverable is an input to the other (no method, type, migration, route, or fixture the other needs).
- They do not edit the same files.
- They do not share a schema or migration the other reads.
- One's tests do not need the other to already be present.

Independence is a positive claim — name why they don't depend.

Sequence numbers stay two-digit and unique (`01`, `02`, …). Assign them in a stable reading order: shared groundwork first, then independent slices, change-audit last. A
higher number does **not** mean "run after the lower number" unless `blocked_by` says so. Two slices that both depend only on `01` get distinct sequence numbers and **no**
edge between them, so `plan-execute` can spawn them together.

Splitting independent slices **is** useful in this mode when they can run together. Still do not split atomic work (a migration and its seeder, a single-line config
change) and never split by layer.

Unchanged:

- Every sub-plan is a vertical slice.
- Shared groundwork that cannot live inside the first slice may be sub-plan `01`, as small as possible.
- Change-audit is the last sub-plan, blocked by every preceding sub-plan, and blocks nothing (except plan-directory cleanup).

### Confirming the split (Step 2 addition)

When presenting the proposed split, keep the existing table, and add a one-line note naming each set of sub-plans that share no `blocked_by` edge and may run together:

```
May run together: 02-slug.md, 03-slug.md, 04-slug.md
```

If no such set exists, the graph is linear — say so. The write format in Step 3 does not change.

---

## plan-execute

Overrides Step 2, Step 3, and the sequential-only orchestration rule in `plan-execute` `SKILL.md` (one-at-a-time spawn, wait-then-next, "sequential execution only", and
the quality-regression paragraph — the user opted in; proceed). You still do not implement, `.agent-instructions.md` is written first, the branch check runs once before
any spawn, templates A/B/retry are unchanged, Step 3c failure classes are unchanged, Step 4 report and Step 5 deletion are unchanged, and `blocked_by` is still
non-negotiable.

### Step 2 — Build the execution graph as waves

Resolve the dependency graph into **waves** using topological sort. A wave is every pending or partial sub-plan whose `blocked_by` set is already satisfied (`complete`
plans from Step 1b count as satisfied). Treat `complete` plans as done and exclude them from every wave.

If a cycle is detected, stop with an error listing the cycle.

If every wave has size 1, execution matches sequential — print the order as a single list and run it that way. Do not pretend there is parallelism.

Print the wave plan before executing:

```
## Execution plan (parallel)

Wave 1:
  01-slug.md

Wave 2 (parallel, 3 agents):
  02-slug.md
  03-slug.md
  04-slug.md (partial)

Wave 3:
  05-change-audit.md

[06-slug.md skipped — already complete]
```

Label a wave `(parallel, N agents)` only when N > 1.

### Step 3 — Execute one wave at a time

A plan never starts before all its blockers are complete. Within a wave, spawn every ready sub-plan together. The next wave starts only after every agent in the current
wave has returned.

#### 3a — Spawn the wave

Write `.agent-instructions.md` once before the first spawn (same content as `plan-execute` `SKILL.md`). On each `Agent` call, pick a model that fits the work — prefer
using fewer tokens while still doing the job well.

- Wave of one: spawn one `general-purpose` sub-agent, wait, evaluate (same as sequential Step 3a).
- Wave of several: make one `Agent` tool call per sub-plan **in the same turn**, then wait for all of them. Use Template A or B from `plan-execute` `SKILL.md` per the
  sub-plan's Step 1b status. Each prompt stays self-contained (file path, not file content).

#### 3b — Wait for the whole wave

Do not start the next wave, and do not spawn anything outside this wave, until every in-flight agent has returned.

#### 3c — Detect failure after the wave

Inspect every returned result using the same failure classes as `plan-execute` `SKILL.md`.

- All succeeded: mark each sub-plan complete and start the next wave.
- Any failed: do not start the next wave. Report every failure (same verbose block per file as `plan-execute` `SKILL.md`). Use `AskUserQuestion` once, listing each failed
  file, with the same three options (retry / skip / abort). Retry re-spawns only the failed members with the retry template — successful members of the wave stay done.
  Skip marks the failed members skipped, warns that downstream plans may be affected, and continues to the next wave. Abort stops all orchestration.

### Orchestration rules that still bind

- Never implement code yourself.
- Check the branch yourself, once, before the first sub-agent — same rule as `plan-execute` `SKILL.md`.
- Never branch again after that.
- Always write `.agent-instructions.md` first.
- Never read `plan.md`.
- Dependencies are non-negotiable. Do not start a plan before all its blockers are marked complete.
- Pass file paths, not content.
- Fail loudly. After a wave, any failed member blocks the next wave until the user chooses retry, skip, or abort.
