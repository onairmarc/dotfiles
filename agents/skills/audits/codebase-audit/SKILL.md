---
name: codebase-audit
author: Aaron Francis
description: "Codebase auditing: it validates, dedupes, and ranks audit results"
---

Audit this entire codebase for materially useful simplifications in its data structures, state representation, control flow, algorithms, and ownership.

This is an audit-only exercise. Do not edit files, run tests, implement recommendations, commit, or push. Read-only inspection commands are allowed.

You are the coordinator. Continue until the complete codebase has been reviewed and the final audit is validated.

# 1. Establish the coverage contract

Inspect the repository and inventory every identifiable subsystem.

Read [`audit-commons/inventory.md`](../audit-commons/inventory.md) for the subsystem fields, status values, and scratchpad structure. Note: the `fix applied` status does
not apply to this skill — it is read-only.

Include frontend, backend, shared infrastructure, platform bridges, generated-contract ownership, and test/tooling infrastructure where materially relevant.

# 2. Run bounded subsystem reviews

Read [`audit-commons/worker-brief.md`](../audit-commons/worker-brief.md) for dispatch rules, the worker brief, and the output schema.

No additional scope qualifier — workers review the full subsystem.

# 3. Validate and synthesize

Read [`audit-commons/validation.md`](../audit-commons/validation.md) and follow the validation and synthesis pass.

# 4. Audit the audit

Read [`audit-commons/validation.md`](../audit-commons/validation.md) and follow the audit-the-audit pass.

If the coverage pass finds a real omission, add an explicit subsystem row and audit it. Do not hide it by broadening a previously completed boundary.

The audit is complete only when:

- every identifiable subsystem has been reviewed;
- every subsystem has a recommendation or explicit skip;
- every finding has complete evidence, scope, risk, and validation fields;
- duplicates and weak abstractions have been removed;
- priorities and dependencies are internally consistent;
- the repository remains unchanged.
