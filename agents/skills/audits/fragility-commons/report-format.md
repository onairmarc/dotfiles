# Fragility audit report format

Plans that change executable behavior include `## Fragility audit report` immediately after `## Goal`.

The section contains:

- **Executive summary:** audit scope, reviewed subsystems, counts by severity, highest-impact chains, remediation themes, and evidence limits.
- **Validated findings:** severity, exact source and contract, reachability proof, propagation chain, concrete outcome, affected interface, and required behavior.
- **Simplification assessment:** whether simplification was evaluated, the selected target shape, or why retaining the current shape is safer.
- **Coverage record:** explicit skips and rejected speculative candidates.
- **Remediation order:** dependencies and the order in which findings must be addressed.

The plan is the report artifact. Do not create a duplicate audit report unless the user asks for one.
