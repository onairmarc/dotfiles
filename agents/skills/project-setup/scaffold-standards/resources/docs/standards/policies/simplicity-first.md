# Simplicity First

Prefer the simplest implementation that satisfies the requirement; avoid abstraction layers, interfaces, and configuration knobs that exist for hypothetical future
flexibility.

A pattern that adds an interface, a factory, and a registration binding to support "a future second implementation" that never arrives is pure cost — extra files to grep
through, extra indirection at every call site, and an extra place to keep documentation in sync. Three similar lines beat a premature abstraction. When the second
implementation actually arrives, the abstraction is easy to extract; before then, it is a tax.

**Rules:**

- Do not introduce an interface with a single implementation unless mocking it is the explicit goal.
- Do not introduce a configuration flag for behavior that has only one production value.
- Do not introduce a fallback, compatibility shim, or default branch for cases that cannot occur.
- Do not add an abstraction for a single caller. Wait for the pattern to repeat before extracting it. {{GEN:if `module-isolation.md` was written, append to this bullet:
  "**Exception:** a cross-module service method is required from the first caller — see [Module Isolation](./module-isolation.md). That abstraction is a boundary, not
  speculation." Omit the exception entirely if that policy was not written.}}
- Delete dead code rather than commenting it out. Version control remembers.
- A bug fix does not need surrounding refactor or cleanup; keep the diff scoped to what was asked.

> Severity for plan review: **WARN**.
