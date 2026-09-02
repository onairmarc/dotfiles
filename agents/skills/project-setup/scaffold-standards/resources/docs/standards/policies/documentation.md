# Documentation

Every code change carries the documentation update that keeps `AGENTS.md`, `README.md`, the policies, and module docs accurate. Every module owns an `AGENTS.md` and a
`README.md`, and new terms get a glossary entry in the same change.

The documentation surface serves both humans and coding agents. Root `AGENTS.md`, the policy index, sibling standards docs, and module docs let a new contributor ship a
change without paging an owner. Planning and review tooling reads `AGENTS.md` and the policy index to check work against the rules, and module docs guide agents to the
right entry point before they write code. When these files drift, agents make worse decisions with full confidence. Documentation drift is a defect, not a chore.

**Rules:**

- Comments are not documentation. Design rationale and how a subsystem works live in docs, not next to the code. See [Code Comments](./code-comments.md).
- Include the paired documentation update in the same change. A stale doc is worse than none.
- Use a module's `AGENTS.md` as an agent routing index, not technical reference documentation. Point agents to the matching module docs, skills, and policies for each task.
- {{GEN:detect the project's existing documentation organization and state its exact module technical-reference location. The module `README.md` is the documentation
  index, and focused documents own the module's architecture, contracts, workflows, configuration, and integration details. If no convention exists, state that an agent
  must not create or reorganize one without the user's explicit permission. After permission, the agent must use `question` to offer at least three concrete
  organization options that fit the project's module layout, existing files, and tooling; explain why each fits and its tradeoffs; and put the recommended option first,
  labeled `(Recommended)`. The agent implements only the option the user selects.}}
- When changing a module's public surface, such as a service signature, event payload, or contract, update the affected technical reference in the same pull request.
  Touching a module means visiting its documentation index and correcting anything the change makes false.
- Add a new policy or amend an existing policy in `{{DOCS_PATH}}/policies/` as its own file, add a row to [`policies.md`](../policies.md), and regenerate the
  auto-summary block in `AGENTS.md`. The index is the single routing table.
- A new module ships with `AGENTS.md` and `README.md` at minimum. A skeleton is acceptable. Link it from the project's root documentation index.
- New acronyms and project-specific nouns get an entry in [`glossary.md`](../glossary.md) in the same change.
- Cross-cutting or architectural decisions are recorded as an **ADR** (Architecture Decision Record) — never buried in a code comment and never only in a pull-request
  description, both of which are lost the moment the plan that produced them is deleted. An ADR is a durable, numbered Markdown document (distinct from a throwaway
  `{{PLANNING_PATH}}/` plan) that captures the question asked, the options weighed, the decision made, and its consequences. A project-wide decision lives at
  `{{DOCS_PATH}}/decisions/NNNN-<slug>.md`; a decision scoped to one module lives in that module's own `docs/decisions/NNNN-<slug>.md`. Number sequentially from `0001`
  and never renumber a landed ADR. Link the ADR from the owning doc (the module `README.md`/`AGENTS.md` or the standards index) so it is discoverable, and add an
  `ADR` glossary entry the first time the convention appears.

> Severity for plan review: **BLOCK**.
