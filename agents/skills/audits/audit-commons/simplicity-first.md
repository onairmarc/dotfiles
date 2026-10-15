# Simplicity-first lens

**Complexity is the enemy of stability.** Evaluate this lens whenever reviewing code or an implementation plan. Ask: **what is the minimum safe code
change that achieves the required outcome?**

Favor fewer concepts, states, ownership boundaries, dependencies, and control-flow paths. A smaller diff is not automatically simpler when it
preserves or adds complexity that a comparably safe deletion-first design can remove.

## Review rules

1. State the required outcome, its acceptance criteria, and the behavior that must not change.
2. Identify the smallest credible change that achieves the outcome, then trace its callers, callees, registrations, side effects, and tests.
3. State whether that minimum change adds, removes, or keeps complexity the same. Count concepts, state, ownership boundaries, dependencies,
   configuration, and control-flow paths, rather than lines alone.
4. Independently apply [`deletion-first.md`](deletion-first.md). Use its option instead of the additive or complexity-neutral minimum change only
   when it achieves the same outcome, leaves all other system behavior unchanged, and does not materially expand touched call paths, migration
   work, validation scope, or regression risk.
5. Otherwise, use the minimum safe change. Do not widen the change merely to reduce code, and do not preserve complexity solely because the
   smallest diff is easier.
6. Reject speculative flexibility, new layers with one caller or implementation, and resilience mechanisms that do not answer a proved failure mode.
7. Preserve explicit ownership, diagnosability, security boundaries, error behavior, and required tests. A shorter change that weakens any of
   these does not pass this lens.

## Evidence and outcomes

For each evaluation, record the required outcome, the minimum safe change, its complexity effect, the deletion-first alternative, and proof
that all other system behavior remains unchanged. Explain why the chosen option is safer and simpler. Include exact file and line references,
affected callers and interfaces, migration and regression risks, and validation.

Record an explicit skip when no change is needed or the current design is already the smallest clear design for the required outcome.
