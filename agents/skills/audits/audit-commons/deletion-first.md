# Deletion-first design lens

Evaluate this lens whenever reviewing code or an implementation plan. Ask: **if half of the code disappeared, how could the same required outcomes still work?**

Treat “half” as a forcing question, not a line-count target. Prefer the smallest behavior-preserving design that uses the codebase's existing patterns and removes
needless layers, duplicate work, stale compatibility paths, configuration, or state. Do not compress code, weaken checks, or hide complexity to reduce lines.

## Review rules

1. Trace the required behavior from its entry points through callers, callees, registrations, side effects, and tests before judging whether code is necessary.
2. Separate required behavior from historical compatibility, speculative extension points, duplicate branches, wrapper layers, repeated transformations, unused
   configuration, and dead state.
3. Compare the current design with the smallest credible design that preserves the required outcomes, error behavior, security boundaries, observability, and tests.
4. Prefer deleting code, dependencies, configuration, and interfaces over adding a new abstraction. Keep local code when an abstraction would only relocate
   complexity.
5. Preserve clear ownership and explicit control flow. A shorter implementation that is harder to diagnose, test, or safely change does not pass this lens.
6. Do not propose a simplification without exact evidence and a traced migration path for every affected caller, consumer, registration, and test.

## Evidence and outcomes

For each opportunity, record exact file and line references, the behavior that must remain, the code or concept that can disappear, the simpler replacement, affected
callers and interfaces, migration and regression risks, and required tests. For plans, name the files or symbols to remove or avoid creating, the retained behavior,
and the verification that proves equivalence.

Accept only changes that materially reduce the number of concepts, ownership boundaries, states, or duplicated paths. Reject changes that merely rename, relocate, or
conceal complexity. Record an explicit skip when the current design is already the smallest clear design for the required behavior.
