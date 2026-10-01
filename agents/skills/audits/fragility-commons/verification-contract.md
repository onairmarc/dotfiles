# Fragility verification contract

After all behavioral slices and `change-audit` fixes pass their scoped tests, load `fragility-audit` with the `skill` tool and run its `--verify-changes` mode over
every branch change and directly affected call path. Never invoke it through OpenCode, a shell command, or a slash command.

The verification confirms:

- Each remediated finding has its required behavior and focused test coverage.
- Simplified flows still handle every proved error path.
- `change-audit` fixes did not introduce a proved fragile path.
- No new proved fragility finding remains in changed code or directly affected callers and callees.

When verification finds a problem, remediate every accepted finding in the current verification sub-plan. Add or update focused failure-path tests, run the affected
scoped test suite, and repeat verification until no proved finding remains. Do not create, request, or hand off to another plan. Delete the plan directory only after
the clean re-verification passes. If remediation requires a user decision, stop before plan-directory deletion and ask that decision directly; do not turn it into a
planning task.
