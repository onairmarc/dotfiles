# Documentation

Every change carries the documentation update that keeps `AGENTS.md`, `README.md`, the policies, and per-module docs accurate; new terms get a glossary entry in the same
change.

This documentation surface is critical for both humans and coding agents: planning and review tooling reads `AGENTS.md` and the policy index to gate work against the
rules, and per-module docs steer an agent toward the right entry point before it writes code. When those files drift, the agent makes worse decisions with full
confidence. Documentation drift is a defect, not a chore.

**Rules:**

- Public surface — exported functions, types, modules — carries a doc comment stating what it does and any non-obvious contract. Skip the obvious; document the
  surprising.
- When a change alters documented behavior, update the doc in the same change. A stale doc is worse than none.
- Touching a module means visiting that module's own docs and correcting anything the change makes false.
- A new policy goes in `{{DOCS_PATH}}/policies/` as its own file, with a row added to [`policies.md`](../policies.md) — the index is the single routing table.
- New acronyms and project-specific nouns get an entry in [`glossary.md`](../glossary.md) in the same change.
- Cross-cutting or architectural decisions land in `{{DOCS_PATH}}/` or the owning module's doc — never buried in a code comment and never only in a pull-request
  description.

> Severity for plan review: **BLOCK**.
