---
name: user-docs-group
description: Generate or update end-user documentation for a set of implemented features by comparing a directory of plan files against the code that was actually written. Extends the user-docs skill — uses plans to locate and scope what to document, uses the code as the source of truth for UI labels, workflows, and behavior. Invoke when a feature epic has been implemented and you want accurate user-facing docs that reflect reality, not intent.
disable-model-invocation: true
argument-hint: [ path to the plan directory ]
allowed-tools:
  - Read
  - Edit
  - Write
  - AskUserQuestion
  - Glob
  - Grep
  - Agent
  - Bash(test -f *)
  - Bash(test -d *)
  - Bash(cat *)
model: opus
---

# User Docs — Group Mode (extends user-docs)

This skill extends the base `user-docs` skill with plan-driven scoping and code-vs-plan delta analysis.

## File Operation Rules

Read and follow `.agents/skills/file-operations/SKILL.md`.

**Before doing anything else**, read the base skill:

```
.agents/skills/user-docs/SKILL.md
```

Follow every standard, guideline, and verification step defined there. The additions below run **before** you
begin writing documentation — they replace the ad-hoc scoping phase with a structured plan-analysis phase that
tells you exactly what to document and where to look.

---

## Addition: Step 0 — Resolve the plan directory

If `$ARGUMENTS` contains a directory path, use it.

Otherwise, use `AskUserQuestion` to ask the user:

> **Which plan directory should I document?**
> Please provide the path to the directory containing the plan files (e.g. `docs/plans/my-epic`).

Once you have a path:

1. Use `Glob` to find all Markdown files recursively under the directory (pattern: `**/*.md`).
2. If no Markdown files are found, tell the user and stop.
3. Read every discovered file with the `Read` tool to gain full context — this includes plan files,
   sub-plans, design decisions, and any other documentation in the directory.

Also resolve from `$ARGUMENTS` or ask:

- **Docs output path** — where should generated documentation files be written? Default to a `docs/` directory
  alongside the plan directory if not specified. Confirm with the user if the destination is ambiguous.
- **Target audience and domain** — who are the end users, and what domain terminology do they use? Skip if
  inferable from the codebase or plans.

---

## Addition: Step 1 — Extract user-facing scope from plans

Read all plan files in full. Do not treat plans as factual descriptions of what exists — treat them as a
navigational guide to user-facing features. Extract:

1. **Feature boundaries** — which workflows, screens, or user-facing capabilities does this epic touch?
2. **Named UI surfaces** — page names, button labels, field names, menu items, modals, and settings mentioned
   across all plans.
3. **Intended user workflows** — the step-by-step flows described in the plans. Useful for understanding the
   intended experience even when the implementation differs.
4. **Domain terminology** — application-specific language used to describe concepts to end users.

Keep a running list of every named UI surface and workflow found across all plans. This is your **investigation
queue** for Step 2.

---

## Addition: Step 2 — Verify against actual code and build a delta log

For each item in the investigation queue, verify what was actually built using the `user-docs` source
verification checklist (Feature Existence, UI Labels, Workflows, Terminology).

**Maintain a delta log** as you verify:

| Feature / UI Surface | Plan described | Code has | Delta                                                 |
|----------------------|----------------|----------|-------------------------------------------------------|
| ...                  | ...            | ...      | Added / Removed / Renamed / Changed / Not implemented |

Record every deviation. These deltas are the difference between documenting what was planned and documenting
what users will actually experience.

---

## Addition: Step 3 — Audit existing documentation

Before writing anything new:

1. Use `Glob` to find existing end-user documentation files in the project (e.g., `**/*.md` under `docs/`).
2. Read any that correspond to the features in the plans.
3. Flag sections that contradict verified UI labels, workflows, or behavior.
4. If existing documentation is substantially accurate, prefer updating it over replacing it. Only rewrite a
   file if the majority of its content is wrong or the structure cannot accommodate the needed changes cleanly.

---

## Addition: Step 4 — Clarify divergences before writing (if needed)

If verification revealed significant divergences between plans and code, or if scope or output path is unclear,
use `AskUserQuestion` to resolve blockers. Format:

---

**Documentation scope confirmation**

Before writing, I found the following divergences between the plans and the implemented code. Please confirm
how you'd like these handled:

**[Feature / UI Surface]**

> Plan described: *...*
> Code implements: *...*

❓ Should I document the implemented behavior, note the divergence, or skip this feature?

---

Keep questions minimal — only ask when the delta materially affects what to write or where to write it.

---

## Override: Source of truth rule

**Code is truth. Plans are context.**

- Every UI label, button name, field name, menu item, and workflow step must match what is verified in the code
  — not the plan's description.
- If the plan described a user workflow that still matches the implemented flow, document it as written.
- If a plan feature was not implemented, do not document it.
- Never document behavior or UI you cannot verify in the code.

---

## Final summary

After all documentation files are written, present:

```
## Documentation complete ✓

**Plans reviewed:** N
**Features verified:** N
**Docs written:** N (list each file path)
**Docs updated:** N (list each file path)

**Notable deltas from plan:**
- <feature>: <what changed / was not implemented / was added>

All documentation reflects the verified current state of the application.
```

Then ask:

> Documentation has been written to the output directory. Would you like me to cover any additional features,
> adjust scope, or refine any section?

---

**Plan directory / context:** $ARGUMENTS
