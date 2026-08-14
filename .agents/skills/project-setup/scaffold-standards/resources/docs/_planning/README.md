# Planning Directory

This directory holds **feature planning documents** for {{PROJECT_NAME}} — the scaffolding produced before and during implementation of a feature. It is working material,
not the documentation of record.

## Plans are throwaway, not persistent documentation

A plan (`<feature>/plan.md` and any split sub-plans) exists to drive one implementation effort. It is **never** the durable documentation for the feature it describes.
Treat plans as consumable scaffolding:

- **Durable docs are created separately.** Every plan must include explicit steps that write the lasting documentation into its real home — `{{DOCS_PATH}}/`, the project
  `README.md`/`AGENTS.md`, the [glossary]({{DOCS_PATH}}/glossary.md), or a module's own doc. The plan directs where that documentation lands; it does not itself serve as
  that documentation.
- **Do not point durable docs or code comments at a plan.** A `{{PLANNING_PATH}}/<feature>/plan.md` path must not appear as a reference in shipped docs or code — the plan
  will be deleted.
- **Delete the plan once implemented.** After a feature's plan is implemented and verified, delete its
  `{{PLANNING_PATH}}/<feature>/` directory in the same change that lands the implementation and its durable docs. A missing or staged-deleted plan directory at commit
  time is intentional — do not restore it.

## The plan index — keep it in sync

`_index.md` holds the **Plans** table that indexes every active plan directory. That table is the single source of truth for what plans exist and where each one stands,
so it must be updated in lockstep with the plans themselves:

- **When a plan is created** — add a row to the Plans table with status `Not Started`, and refresh the recommended implementation order.
- **When a plan is updated** — adjust its status (`Not Started` → `In Progress` → `Blocked`, etc.) to match reality, and re-evaluate the recommended implementation order,
  since scope or dependency changes can reorder what should be worked on next.
- **When a plan is implemented** — because the `{{PLANNING_PATH}}/<feature>/` directory is deleted in the implementation change, **remove its row from the Plans table in
  the same change**. A plan that no longer has a directory must not linger in the index.

### Recommended implementation order

`_index.md` must always carry a **recommended plan implementation order** so a developer can tell at a glance what to work on next. Recompute this order whenever a plan
is created or updated — ranking by dependency (plans that unblock others come first), then by value and readiness. Keep it adjacent to the Plans table.

### Resync sibling plans during implementation

Implementing a plan changes the code the other plans were written against. Every plan implementation must therefore **resync all other active plans** against the new code
so the backlog stays continuously accurate — reconcile any drift the just-landed changes introduced into each remaining plan directory. Fold the resync into the
implementation work so no sibling plan is left describing code that no longer exists.

## What does live here permanently

- **`_index.md`** — the running plan index (Plans table + recommended implementation order) described above.
- {{GEN:any other permanent planning artifacts this project wants here — e.g. a product-vision/northstar doc, an idea backlog. Ask the user; omit this bullet if none.}}

Everything else under `{{PLANNING_PATH}}/` is a transient per-feature plan directory subject to the lifecycle above.
