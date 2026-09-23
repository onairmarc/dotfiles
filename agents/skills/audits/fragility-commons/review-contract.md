# Fragility review contract

Treat every failed check below as a BLOCK:

- A plan produced from a fragility audit lacks `## Fragility audit report` in the required position.
- A reported finding lacks a proven source, reachability proof, propagation trace, or concrete outcome.
- A proposed remediation does not map to a finding or changes its required behavior without explaining why.
- Simplification was not evaluated where state, branching, ownership, or propagation complexity contributes to the finding.
- The target flow does not define error handling, cleanup, logging, observable behavior, and focused tests.
- A planned test covers only the happy path or asserts no behavior for the proved failure.
- A claim is speculative rather than proved under [`proof-contract.md`](proof-contract.md).

For a plan that did not originate in the `fragility-audit` skill, require an audit-only handoff before finalizing it whenever the plan changes executable behavior.
