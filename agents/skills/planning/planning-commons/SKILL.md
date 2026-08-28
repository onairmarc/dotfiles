---
name: planning-commons
description: Canonical shared references for the planning skills — path resolution and standards discovery, the AskUserQuestion review loop and BLOCK/WARN severity, the plan/sub-plan document format, the parallel-execution overlay, and TodoWrite task tracking. Read the relevant file at the start of any planning skill that resolves repo paths, runs an interactive review loop, emits/consumes a plan file, runs the parallel branch of plan-split / plan-execute, or tracks skill steps to completion, so the rule lives in one place instead of being restated per skill.
---

# Planning Commons

A small library of reference documents shared across the planning skills (`feature-planning`, `northstar`, `pm-review`, `plan-review`,
`plan-resync`, `plan-split`, `plan-execute`). Each doc is the single source of truth for one cross-cutting concern; a skill reads the one it needs at the point it needs
it, exactly as skills already read `~/.config/opencode/skills/delivery-constraints/SKILL.md` and
`~/.config/opencode/skills/file-operations/SKILL.md`.

| Concern                                           | File                               | Read it when…                                                                                                              |
|---------------------------------------------------|------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| Repo path resolution + standards/policy discovery | [`paths.md`](paths.md)             | a skill must locate the planning dir, product-docs dir, discovery-brief dir, northstar, or the project's coding standards. |
| Interactive review loop + BLOCK/WARN severity     | [`review-loop.md`](review-loop.md) | a skill asks the user via `AskUserQuestion`, iterates lenses until clean, or classifies a finding as BLOCK/WARN.           |
| Plan + sub-plan document format                   | [`plan-format.md`](plan-format.md) | a skill emits a plan (`feature-planning`), emits sub-plans (`plan-split`), or parses them (`plan-execute`).                |
| Parallel execution overlay                        | [`parallel.md`](parallel.md)       | `plan-split` or `plan-execute` after the user selected Yes at the parallel-execution question (default is No).            |
| Task tracking (TodoWrite)                         | [`task-tracking.md`](task-tracking.md) | `plan-split`, `plan-execute`, `plan-review`, or `plan-resync` starts — seed the list before Step 0 and keep it current. |

These docs describe *how the skill operates*; they are never pointed at from an emitted artifact (a plan, a sub-plan,
`.agent-instructions.md`). Emitted artifacts must remain self-contained — when a template here contains a block to reproduce, the skill copies that block into the
artifact rather than linking back here.
