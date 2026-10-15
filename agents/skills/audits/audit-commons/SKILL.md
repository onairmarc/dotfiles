---
name: audit-commons
description: >-
  Canonical shared references for audit and planning skills — subsystem inventory format, worker review brief and output schema,
  validation/synthesis passes, 2 AM outage readiness, deletion-first design, and simplicity-first design. Read each relevant file at the required review point.
---

# Audit Commons

A small library of reference documents shared across audit, review, and planning skills. Each document is the single source of truth for one cross-cutting concern.
Read the document at the point it applies.

- [Subsystem inventory fields and scratchpad](inventory.md): inventory subsystems and create the tracking scratchpad.
- [Worker review brief and output schema](worker-brief.md): dispatch bounded subsystem review workers.
- [Validation, synthesis, and audit-the-audit](validation.md): validate worker findings, deduplicate, and run coverage and materiality passes.
- [Workflow lenses](workflow-lenses.md): the single entry point for 2 AM outage readiness, deletion-first design, and simplicity-first design.
- [2 AM outage readiness](outage-readiness.md): canonical guidance for diagnosis, recovery, and tired-engineer comprehension.
- [Deletion-first design](deletion-first.md): canonical guidance for a smaller behavior-preserving design.
- [Simplicity-first](simplicity-first.md): canonical guidance for the minimum safe change and equivalent deletion-first options.

These documents describe *how the skill operates*; they are internal process references, not emitted artifacts.
