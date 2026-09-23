# Fragility planning contract

For every accepted finding, a plan must define the remediation before implementation begins:

- Concrete files, types, methods, interfaces, and control flow to change.
- The target simplified representation or flow when simplification is selected.
- The exact error boundary, recovery behavior, cleanup, logging, and caller or user-visible result.
- How partial work is prevented, rolled back, retained, or made retryable.
- Focused tests that reproduce the proved failure path and assert the required behavior.

Analyze the proposed target flow for fragility during planning. State every proved error path the new flow can receive and how it is handled.
Do not defer this analysis to the implementation agent.

The plan maps each remediation slice and acceptance criterion to the finding IDs it resolves. A slice is not complete until its failure-path tests pass.
