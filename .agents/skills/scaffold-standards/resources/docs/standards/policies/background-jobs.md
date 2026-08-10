# Background Jobs

Every unit of background work is idempotent and safe to retry, declares its retry policy explicitly, and inherits its ambient context rather than re-establishing it.

Worker crashes, deploys, and network blips will replay a job. A job that double-charges a card, double-sends an email, or double-applies a ledger entry on retry is a
defect, not bad luck. An explicit retry policy makes the failure behavior a decision rather than whatever the framework's default happens to be this version. Ambient
context — the tenant, the account, the request correlation id — is propagated by the dispatch machinery; re-establishing it inside the handler is both redundant and
dangerous, because a recycled worker can pin the wrong value.

**Rules:**

- The handler body is safe to run twice without doubling its effect — guard with a lock or a state check before the mutation. See
  [Concurrency Guards](./concurrency-guards.md).
- Retry count, backoff, and timeout behavior are declared explicitly on every job rather than inherited from a framework default.
- Do not re-establish ambient context inside the handler; it is inherited from the dispatching context.
- Jobs take typed transfer objects or primitive scalars as their payload — never a live, serialized domain object whose state will be stale on retry. See
  [Data Transfer Objects](./data-transfer-objects.md).
- Let failures propagate so the retry machinery engages; do not catch-and-swallow to force a false success. See [Error Handling](./error-handling.md).
- Log the start and terminal outcome of each job with the correlating identifiers in structured context.
- {{GEN:name this project's background-work mechanism, where job types live given {{MODULE_LAYOUT}}, the exact properties/attributes that declare the retry policy, and
  how ambient context is propagated. Detect and confirm.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a job with no retry policy that re-establishes context and mutates unguarded ("Bad") with the same job declaring
its retry policy, inheriting context, and guarding the mutation ("Good").}}

> Severity for plan review: **WARN**.
