# Fragility sub-plan contract

For every slice that resolves a fragility finding, `plan-split` copies the relevant details into the sub-plan's `## Context`, `## Steps`, and acceptance criteria:

- Finding IDs and the proved failure chain.
- The required simplified target shape, when selected.
- Exact recovery, cleanup, logging, and observable failure behavior.
- The focused failure-path tests and runner command.

The sub-plan must stand alone. An implementing agent must not need the master plan to know why the change exists or how the error path behaves.

`plan-execute` binds each coding agent to these details and treats missing failure-path acceptance criteria as an incomplete sub-plan.
