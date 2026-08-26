# Error Handling

Errors are raised for genuinely exceptional conditions, caught only where the code can act on them, and always reach an observer — never swallowed. Control flow that is a
normal, expected outcome is expressed with a return value, not by raising.

A handler that logs nothing and re-raises nothing turns a failure into silence: the operation reports success, no alert fires, and the only evidence is missing data
discovered days later. The cost of one swallowed error is a support ticket that no log line explains. Catch narrowly, do something real in the handler, and let anything
you cannot handle propagate to the framework's reporter with its context intact.

**Rules:**

- **Do not swallow.** An empty handler, or one that returns a null/empty value with no log and no re-raise, is forbidden. If a failure is safely ignorable, log it at
  `warn` with a reason and return the fallback explicitly.
- Catch the narrowest type you can act on, at the layer that can act on it — not a blanket catch wrapped around a whole function to keep going.
- When you catch and cannot recover, log at `error` with the failure detail in the structured context (see [Structured Logging](./structured-logging.md)), then re-raise
  or fail the operation — do not continue as if it succeeded.
- Do not use errors for expected control flow. A missing optional record, a validation miss, a "not found" — return an empty value or a result type; do not
  raise-and-catch to branch.
- Validate inputs at the boundary — public entry points, deserialization, request handlers — not repeatedly in every internal callee. See
  [Input Validation](./input-validation.md).
- Background work lets failures propagate so the retry machinery engages; do not catch-and-swallow to force a false success.
- User-facing surfaces translate a caught domain failure into a message or error response — and still log the underlying error before doing so.
- {{GEN:the project's error model for {{PRIMARY_LANGUAGE}} — exceptions vs. result types, the base error types, the reporter errors reach, and the boundary at which
  unhandled errors are converted to a response. Author from the stack and confirm.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a blanket catch that swallows and reports false success, with an expected miss raised as an error ("Bad"), against
the same function where the expected miss is a returned result and the unrecoverable failure is logged and re-raised ("Good").}}

> Severity for plan review: **BLOCK**.
