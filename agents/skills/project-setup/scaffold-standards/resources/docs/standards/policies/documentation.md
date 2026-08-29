# Documentation

Every change carries the documentation update that keeps `AGENTS.md`, `README.md`, the policies, and per-module docs accurate; new terms get a glossary entry in the same
change.

This documentation surface is critical for both humans and coding agents: planning and review tooling reads `AGENTS.md` and the policy index to gate work against the
rules, and per-module docs steer an agent toward the right entry point before it writes code. When those files drift, the agent makes worse decisions with full
confidence. Documentation drift is a defect, not a chore.

**Rules:**

- Comments are not documentation. Design rationale and how a subsystem works live in docs, not next to the code. See [Code Comments](./code-comments.md).
- When a change alters documented behavior, update the doc in the same change. A stale doc is worse than none.
- Touching a module means visiting that module's own docs and correcting anything the change makes false.
- A new policy goes in `{{DOCS_PATH}}/policies/` as its own file, with a row added to [`policies.md`](../policies.md) — the index is the single routing table.
- New acronyms and project-specific nouns get an entry in [`glossary.md`](../glossary.md) in the same change.
- Cross-cutting or architectural decisions are recorded as an **ADR** (Architecture Decision Record) — never buried in a code comment and never only in a pull-request
  description, both of which are lost the moment the plan that produced them is deleted. An ADR is a durable, numbered Markdown document (distinct from a throwaway
  `{{PLANNING_PATH}}/` plan) that captures the question asked, the options weighed, the decision made, and its consequences. A project-wide decision lives at
  `{{DOCS_PATH}}/decisions/NNNN-<slug>.md`; a decision scoped to one module lives in that module's own `docs/decisions/NNNN-<slug>.md`. Number sequentially from `0001`
  and never renumber a landed ADR. Link the ADR from the owning doc (the module `README.md`/`AGENTS.md` or the standards index) so it is discoverable, and add an
  `ADR` glossary entry the first time the convention appears.

> Severity for plan review: **BLOCK**.
