# Architecture decisions

This directory holds accepted Architecture Decision Records (ADRs): durable explanations of significant technical decisions and the alternatives rejected. Plans under
`{{PLANNING_PATH}}/` are temporary delivery scaffolding; record decisions here when their reasoning must survive after implementation.

Create an ADR when a change establishes or changes a cross-module boundary, a public contract, a system-wide runtime choice, a meaningful data-model invariant, or a
trade-off future contributors might otherwise undo. Do not create one for a local implementation detail that the code already makes clear.

Name project-wide ADRs `NNNN-<slug>.md`, using the next four-digit number. Put a module-specific ADR in that module's `docs/decisions/` directory when only that module
owns the decision.

Each ADR uses this shape:

```md
# NNNN - Short decision name

Status: Accepted

## Context

Describe the problem, constraints, and relevant alternatives.

## Decision

State the decision precisely, including the boundaries and behavior it establishes.

## Consequences

List the resulting commitments, costs, migrations, and follow-up constraints.
```

When an ADR supersedes another, link to both records and state exactly which decision or section changed.
