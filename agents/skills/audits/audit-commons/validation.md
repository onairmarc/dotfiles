# Validation, Synthesis, and Audit-the-Audit

The coordinator's post-review passes. Applies identically to both whole-repo and change-scoped audits; scope-specific adjustments (e.g.
"within the changed files") are noted inline.

---

## Validate and synthesize

The coordinator must independently verify every finding against the current repository before accepting it.

Reject, narrow, or demote recommendations that are vague, duplicate another finding, misunderstand intentional semantics, or merely
relocate complexity.

Record skips as completed coverage. Deduplicate overlapping findings and assign each accepted recommendation to one authoritative
subsystem.

Continue opening bounded review batches until every inventory row is complete.

---

## Audit the audit

Before finalizing (or, for change-audit, before implementing), run fresh independent passes for:

- coverage completeness and missing subsystem boundaries;
- duplication and ownership overlap;
- materiality and over-abstraction;
- schema completeness;
- dependency-aware priority ranking.

If the coverage pass finds a real omission, add an explicit subsystem row and audit it. Do not hide it by broadening a previously completed
boundary.

Rank the final recommendations by concrete impact, confidence, implementation effort, blast radius, and prerequisites. Identify the best
implementation order (or, for codebase-audit, the best first implementation slices).
