# Task tracking

How `plan-split`, `plan-execute`, `plan-review`, and `plan-resync` use `todowrite` so a run cannot quietly skip a step. This file is the single source of truth for the
protocol and the starter lists; each skill points here and names its starter.

Read this file at the start of the skill, **before Step 0** (before Step 0a in `plan-split`). Seed the list from the starter named below, then keep it current through
every step.

---

## Protocol

Call `todowrite` with the full `todos` array on every change.

- **Seed first.** Write the starter list (all `pending`) before doing any other work in the skill.
- **One `in_progress`.** Mark the current step `in_progress` as you start it. No second item is `in_progress` at the same time.
- **Complete only on evidence.** Mark `completed` only after that step's completion criterion in the skill is actually met — never on intent. A starter item is complete
  when its matching step in the skill is complete.
- **Expand when work fans out.** When a step produces N units (sub-plan files, sub-plans to execute), replace that one parent item with one item per unit. Do not hide N
  units inside a single checkbox.
- **Cancel skips.** If a step is skipped for a reason the skill already names (first-run skip, no optimization match, user abort, delete withheld because of failures),
  mark that item `cancelled` — do not leave it `pending`.
- **The skill is not done** while any item is `pending` or `in_progress`. Finish or cancel every item before the skill's final output.

Do not invent extra items for work the skill does not name. Do not drop a starter item because it looks obvious.

---

## plan-split starter

Seed before Step 0a:

| content                                     | priority |
|---------------------------------------------|----------|
| Ask whether parallel execution is permitted | high     |
| Resolve the plan file                       | high     |
| Analyze and decompose the plan              | high     |
| Confirm the proposed split                  | high     |
| Write the sub-plan files                    | high     |
| Output the final summary                    | medium   |

After the user approves the split, replace **Write the sub-plan files** with one item per `NN-slug.md`. An item is complete when that file is on disk with the dependency
header, delivery-constraints block, steps, and acceptance criteria the skill requires. All files written → then the summary item.

---

## plan-execute starter

Seed before Step 0:

| content                                           | priority |
|---------------------------------------------------|----------|
| Resolve the sub-plans directory                   | high     |
| Discover and parse sub-plan files                 | high     |
| Check what is already implemented                 | medium   |
| Reconfirm whether parallel execution is permitted | high     |
| Build the execution order                         | high     |
| Execute the sub-plans                             | high     |
| Output the final report                           | medium   |
| Delete the consumed plan directory                | medium   |

Cancel **Check what is already implemented** on a first run (the skill skips it). After Step 2, replace **Execute the sub-plans** with one item per sub-plan in execution
order (include `(partial)` in the content when Step 1b said so). An item is complete when that sub-agent returned success. Cancel a sub-plan item when the user chooses
skip; on abort, cancel every remaining sub-plan item. Cancel **Delete the consumed plan directory** when the skill withholds deletion (any failure or skip-as-incomplete).

---

## plan-review starter

Seed before Step 0:

| content                                 | priority |
|-----------------------------------------|----------|
| Resolve the plan file                   | high     |
| Discover project standards and policies | high     |
| Lens 0 — standards and policy           | high     |
| Lens A — ambiguity                      | high     |
| Lens B — contradictions                 | high     |
| Lens C — missing information            | high     |
| Lens D — scope and completeness         | high     |
| Lens E — delivery constraints           | high     |
| Compile and group questions             | high     |
| Review loop until clean                 | high     |
| Final confirmation                      | medium   |
| Performance optimization pass           | high     |

A lens item is complete when every finding from that lens is recorded (or you have confirmed the lens has none). Run every lens; do not mark a later lens complete because
an earlier one was noisy. If Step 2 finds the plan already complete, cancel the review-loop, confirmation, and optimization items after telling the user, and stop. Cancel
**Performance optimization pass** when no project-type check matches.

---

## plan-resync starter

Seed before Step 0:

| content                                | priority |
|----------------------------------------|----------|
| Resolve the plan file                  | high     |
| Establish the codebase baseline        | high     |
| Lens A — already implemented           | high     |
| Lens B — stale references              | high     |
| Lens C — invalidated assumptions       | high     |
| Lens D — newly relevant code           | high     |
| Lens E — ordering and dependency drift | high     |
| Lens F — standards and policy drift    | high     |
| Lens G — delivery constraint drift     | high     |
| Classify mechanical vs ask             | high     |
| Review loop until clean                | high     |
| Final confirmation                     | medium   |

A lens item is complete when every drift point from that lens is recorded (or you have confirmed the lens has none). If Step 3 finds the plan already in sync, cancel the
review-loop and confirmation items after telling the user, and stop.
