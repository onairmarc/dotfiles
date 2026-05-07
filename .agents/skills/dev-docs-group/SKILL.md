---
name: dev-docs-group
description: Generate or update developer documentation for a set of implemented features by comparing a directory of plan files against the code that was actually written. Extends the dev-docs skill — uses plans to locate and scope what to document, uses the code as the source of truth. Invoke when a feature epic has been implemented and you want accurate docs that reflect reality, not intent.
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
  - Bash(find * -name "*.csproj" -type f)
model: opus
---

# Dev Docs — Group Mode (extends dev-docs)

This skill extends the base `dev-docs` skill with plan-driven scoping and code-vs-plan delta analysis.

**Before doing anything else**, read the base skill:

```
.agents/skills/dev-docs/SKILL.md
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

1. Use `Glob` to find all `plan.md` files recursively under the directory (pattern: `**/plan.md`).
2. If no `plan.md` files are found, tell the user and stop.
3. Read every discovered plan file with the `Read` tool.

Also resolve from `$ARGUMENTS` or ask:

- **Docs output path** — where should generated documentation files be written? Default to a `docs/` directory
  alongside the plan directory if not specified. Confirm with the user if the destination is ambiguous.
- **Product/stack context** — application name, tech stack, or team conventions not inferable from the code.
  Skip if the codebase makes the stack obvious.

---

## Addition: Step 1 — Extract intent and scope from plans

Read all plan files in full. Do not treat plans as factual descriptions of what exists — treat them as a
navigational guide to the codebase. Extract:

1. **Feature boundaries** — which logical areas, modules, or services does this epic touch?
2. **Named artifacts** — class names, file paths, method names, config keys, routes, events, jobs, tables, and
   API endpoints mentioned across all plans.
3. **Intended behaviors** — the "why" and design rationale described in the plans. Useful for documenting intent
   even when implementation details differ.
4. **Integration points** — how each feature is meant to connect to the rest of the system.

Keep a running list of every named artifact and file path found across all plans. This is your **investigation
queue** for Step 2.

---

## Addition: Step 2 — Verify against actual code and build a delta log

For each item in the investigation queue, verify what was actually built using the `dev-docs` source verification
checklist (Signatures & Interfaces, Configuration, Behavior, Error States, Naming).

**Maintain a delta log** as you verify:

| Artifact | Plan said | Code has | Delta                                                 |
|----------|-----------|----------|-------------------------------------------------------|
| ...      | ...       | ...      | Added / Removed / Renamed / Changed / Not implemented |

Record every deviation. These deltas are the difference between documenting what was planned and documenting
what exists.

---

## Addition: Step 3 — Audit existing documentation

Before writing anything new:

1. Use `Glob` to find existing documentation files in the project (e.g., `**/*.md` under `docs/`).
2. Read any that correspond to the features in the plans.
3. Flag sections that contradict the verified code.
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

**[Feature / Artifact]**

> Plan described: *...*
> Code implements: *...*

❓ Should I document the implemented behavior, note the divergence, or skip this artifact?

---

Keep questions minimal — only ask when the delta materially affects what to write or where to write it.

---

## Override: Source of truth rule

**Code is truth. Plans are context.**

- Every class name, method name, parameter name, config key, env var, and route must match the verified code
  exactly — not the plan's description.
- Code examples must reflect actual signatures and behavior.
- If the plan described design rationale that still applies to the implemented code, include it as the "why."
- If a plan feature was not implemented, do not document it.
- Never document behavior you cannot verify in the code.

---

## Final summary

After all documentation files are written, present:

```
## Documentation complete ✓

**Plans reviewed:** N
**Code surfaces verified:** N
**Docs written:** N (list each file path)
**Docs updated:** N (list each file path)

**Notable deltas from plan:**
- <artifact>: <what changed / was not implemented / was added>

All documentation reflects the verified current state of the code.
```

Then ask:

> Documentation has been written to the output directory. Would you like me to cover any additional surfaces,
> adjust scope, or refine any section?

---

**Plan directory / context:** $ARGUMENTS
