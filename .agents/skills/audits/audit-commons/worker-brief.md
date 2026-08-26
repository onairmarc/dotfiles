# Worker Review Brief

The standard brief dispatched to every bounded subsystem review worker. Both audit skills use this verbatim; scope qualifiers (whole-repo
vs. changed-files-only) are prepended by the calling skill.

---

## Dispatch rules

Use fresh, read-only agents where available. Pick a model that fits the work — prefer using fewer tokens while still doing the job well. Give every worker one distinct
subsystem with an exact, non-overlapping ownership boundary.

Keep concurrency bounded to the number of lanes you can actively coordinate. Use one consolidated wait mechanism, do not interrupt
productive workers merely because they are slow, and close completed workers after harvesting their results.

---

## Brief (send to each worker)

Review the assigned subsystem for at most two materially useful simplifications in its data structures, state representation, or organizing
model.

Inspect its implementation, public interfaces, major call sites, and existing tests. Stay within the assigned ownership boundary. You may
identify cross-subsystem concerns, but do not expand the scope to solve them.

Look for:

- scattered booleans or nullable fields that permit invalid combinations and should become a state machine or discriminated union;
- repeated assumptions about object shape that need a shared typed model;
- duplicated branching that a small map, registry, reducer, or command model would remove;
- unclear state or behavior ownership that a small module boundary would clarify;
- repeated scans, transformations, or lookups where a more appropriate collection or index would materially simplify behavior;
- lifecycle, concurrency, or async states whose representation permits stale or contradictory state.

Do not force an abstraction. Prefer boring local code when it is already clear.

Do not recommend changes solely for stylistic consistency, hypothetical extensibility, minor line-count reduction, or moving existing
branching behind a new type.

Return at most two opportunities. If nothing clearly meets the threshold, return `skip`.

---

## Output schema (required per recommendation)

For every recommendation, provide:

1. Verdict: recommend or skip.
2. Evidence with exact file and line references.
3. Current complexity or invalid states.
4. Proposed representation and why it is simpler.
5. Smallest credible implementation scope, including affected files and interfaces.
6. Regression risks and migration concerns.
7. Existing and additional validation required.
8. Confidence: high, medium, or low.
