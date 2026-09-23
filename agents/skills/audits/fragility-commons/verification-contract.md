# Fragility verification contract

After all behavioral slices and `change-audit` fixes pass their scoped tests, load `fragility-audit` with the `skill` tool and run its `--verify-changes` mode over
every branch change and directly affected call path. Never invoke it through OpenCode, a shell command, or a slash command.

The verification confirms:

- Each remediated finding has its required behavior and focused test coverage.
- Simplified flows still handle every proved error path.
- `change-audit` fixes did not introduce a proved fragile path.
- No new proved fragility finding remains in changed code or directly affected callers and callees.

When verification finds a problem, stop before plan-directory deletion. Keep the plan directory and create a new fragility remediation plan from
the validated findings.
