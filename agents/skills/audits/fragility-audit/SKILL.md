---
name: fragility-audit
description: Audit a codebase or supplied path for proven unhandled failure paths, then create an evidence-based remediation plan. Invoke this through the skill tool, never as an OpenCode command.
---

# Fragility audit

Audit the repository root by default, or the file or directory supplied in `$ARGUMENTS`. Review existing and newly changed code equally.

This is read-only. Do not edit application code, run tests, commit, or push. Read-only inspection commands are allowed.

Read `~/.agents/skills/fragility-commons/proof-contract.md` before reviewing a failure path. Read
`~/.agents/skills/fragility-commons/report-format.md` before reporting.

## Modes

- **Default:** perform the audit, load `feature-planning` with the `skill` tool, and create a remediation plan that embeds the report.
- **`--audit-only`:** perform the audit and return the validated report to the calling planning skill. Do not create a plan.
- **`--verify-changes`:** inspect branch changes and directly affected call paths after implementation. Follow
  `~/.agents/skills/fragility-commons/verification-contract.md`.

## 1. Establish coverage

Inventory every identifiable subsystem within the ownership scope. Read `audit-commons/inventory.md` for the inventory and scratchpad contract.

For each subsystem, record its entry points, public interfaces, error-producing dependencies, error boundaries, callers, framework registrations, and tests.
Read code outside the ownership scope when needed to prove a caller, callee, registration, or observed outcome. Do not report findings outside the ownership scope.

## 2. Run bounded reviews

Use fresh, read-only workers where available. Give each worker one exact, non-overlapping subsystem.

Require each worker to trace synchronous throws, rejected async work, typed error results, validation failures, cancellation, transaction and cleanup failures,
event and callback failures, and partial-success paths only when the code proves they exist. Require the proof contract for every candidate.

Workers return at most two findings or `skip`. Each finding includes its proof chain, current handling, concrete outcome, simplification assessment,
smallest remediation scope, focused tests, severity, confidence, and dependencies.

## 3. Validate and synthesize

Independently retrace every finding. Reject, narrow, or merge findings that are speculative, duplicate another chain, misunderstand intentional behavior, or lack a
concrete outcome. Record explicit skips and rejected candidates as completed coverage.

Rank accepted findings by impact, reachability, confidence, blast radius, remediation effort, and dependencies.

## 4. Audit the audit

Use fresh independent passes to check missing subsystem boundaries, framework registrations, duplicate chains, proof gaps, report completeness, and ranking.
Add a distinct inventory row for every proved omission and review it before finalizing.

## 5. Report and hand off

Build the report required by `~/.agents/skills/fragility-commons/report-format.md`.

For `--audit-only`, return that report to the caller. For `--verify-changes`, stop cleanly when no findings remain; otherwise preserve the current plan directory and
create a remediation-plan handoff. For the default mode, load `feature-planning` with the `skill` tool, then provide the validated report, finding IDs, required
behavior, and remediation order. Never invoke OpenCode, a shell command, or a slash command to run either skill.

The audit is complete only when every scoped subsystem has an accepted finding or explicit skip, every finding meets the proof contract, and the
audit-the-audit pass is clean.
