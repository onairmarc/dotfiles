---
name: audit-commons
author: Marc Beinder
description: >-
  Canonical shared references for the audit skills — subsystem inventory format, worker review brief and output schema, and
  validation/synthesis passes. Read the relevant file at the start of any audit skill that inventories subsystems, dispatches review
  workers, or validates and ranks findings, so the rule lives in one place instead of being restated per skill.
---

# Audit Commons

A small library of reference documents shared across the audit skills (`codebase-audit`, `change-audit`). Each doc is the single source of truth for one cross-cutting
concern; a skill reads the one it needs at the point it needs it.

| Concern                                    | File                                 | Read it when…                                                                               |
|--------------------------------------------|--------------------------------------|---------------------------------------------------------------------------------------------|
| Subsystem inventory fields + scratchpad    | [`inventory.md`](inventory.md)       | a skill inventories subsystems and creates its tracking scratchpad.                         |
| Worker review brief + output schema        | [`worker-brief.md`](worker-brief.md) | a skill dispatches bounded subsystem review workers.                                        |
| Validation, synthesis, and audit-the-audit | [`validation.md`](validation.md)     | a skill validates worker findings, deduplicates, and runs coverage/materiality meta-passes. |

These docs describe *how the skill operates*; they are internal process references, not emitted artifacts.
