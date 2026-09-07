---
name: plan-execute
description: Implements all dependency-ordered sub-plans in a directory created by plan-split. Use when asked to execute, run, or implement a split plan.
---

# Plan Execute

Implement the sub-plans yourself, one at a time, in dependency order. Do not delegate implementation to another agent or use `task` for this workflow.

## File operation rules

Read and follow `~/.config/opencode/skills/file-operations/SKILL.md`.

## Plan-file deletion

Read and follow `~/.config/opencode/skills/planning-commons/plan-file-deletion.md`. Preserve the plan directory until every sub-plan succeeds. You may delete it only in
Step 5.

## Delivery constraints

Read and follow `~/.config/opencode/skills/delivery-constraints/SKILL.md`. Every sub-plan must be a complete vertical slice, implemented in place on the current branch,
and verified with the repository's own test tooling.

## Task tracking

Read and follow `~/.config/opencode/skills/planning-commons/task-tracking.md`. Seed the list from the **plan-execute** starter before Step 0, and keep it current
through every step.

---

## Step 0 — Resolve the sub-plans directory

If `$ARGUMENTS` contains a directory path, use it as `$PLAN_DIR`. Otherwise, use `question` to ask which directory produced by `/plan-split` to execute.

Verify that the directory exists. If it does not, stop with an error.

---

## Step 1 — Discover and parse sub-plan files

Parse the sub-plans per the **Dependency contract** in `~/.config/opencode/skills/planning-commons/plan-format.md`.

List all `*.md` files in `$PLAN_DIR`. Exclude `plan.md`. For each remaining file, read it in full and record its filename, numeric sequence prefix, H1 title,
`blocked_by`, `blocks`, and full content. Build the dependency map from each plan to the plans it is waiting on.

Validate that every listed blocker exists, each `blocked_by` and `blocks` edge is mirrored, and the graph has no cycle. Stop with a specific error if any validation fails.

---

## Step 2 — Build the execution order

Topologically sort the dependency map. When several sub-plans are ready, use numeric sequence order. Print the order before implementing:

```
## Execution plan

1. 01-slug.md
2. 02-slug.md
3. 03-slug.md
```

---

## Step 3 — Implement the sub-plans

Before the first change, follow the branch check in the delivery constraints. Then implement each sub-plan in Step 2 order. Do not begin a sub-plan until every blocker
has succeeded.

For every sub-plan:

1. Read the sub-plan again and trace every code path it names before editing, including callers, callees, listeners, consumers, and framework behavior.
2. Load every applicable guardrail skill for the repository's actual stack before editing.
3. Implement the complete vertical slice. Preserve all plan files throughout this step.
4. Run the repository-native tests scoped to the modules touched by that sub-plan. Fix every failure before continuing.
5. Mark the sub-plan complete only after its acceptance criteria and verification pass.

If a sub-plan has already been partly implemented, identify the completed work from the code and implement only the missing behavior. If an ambiguity requires a
significant architectural decision that the sub-plan does not specify, stop and use `question`; do not guess or begin a dependent sub-plan.

---

## Step 4 — Final report

After every sub-plan succeeds, output a one-line-per-item status list:

```
Execution complete — <$PLAN_DIR> — N sub-plans

01-slug.md  done
02-slug.md  done
03-slug.md  done
```

---

## Step 5 — Delete the consumed plan directory

Plans are transient scaffolding, not durable documentation. When every sub-plan succeeded and the repository's planning-lifecycle policy permits it, delete the entire
`$PLAN_DIR` directory in the same change as the implementation. This includes `plan.md` and all sub-plan files.

If any sub-plan did not succeed, do not delete the directory. Leave it intact and report the blocker.

---

**Task:** $ARGUMENTS
