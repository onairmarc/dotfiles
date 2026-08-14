# Concurrency Guards

A concurrency guard is a distributed lock scoped to the entity it protects; database row locks are reserved for the narrow case of an atomic multi-row write inside a
single transaction.

A row lock ties the mutex lifetime to a database transaction, which means the worker holds an open connection for the entire critical section. When that section includes
a slow external call, the connection pool exhausts and throughput collapses. A dedicated lock is cheap, observable, and decouples the mutex from the storage write —
transactions still wrap the actual write for atomicity, but the concurrency guard is a separate layer above it.

**Rules:**

- Concurrency and idempotency guards use the project's distributed lock, acquired with an explicit time-to-live and an explicit wait timeout.
- Lock keys are scoped to the entity (`invoice.charge.{id}`, not `charge`) so unrelated work does not contend.
- Never hold a lock across an unbounded operation. If a slow external call is unavoidable, keep the lock's TTL longer than the call's own timeout and make the work
  idempotent anyway.
- Atomic multi-row writes that must succeed or roll back together are wrapped in a transaction — that is the right tool for atomicity, not for concurrency.
- Do not stack a row lock and a distributed lock on the same critical section; pick one.
- {{GEN:name this project's distributed-lock mechanism and backing store, the exact acquire-and-run idiom, and what happens when the wait timeout expires. Detect and
  confirm.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a row lock held across a slow external call ("Bad") with a scoped distributed lock around the critical section and
a transaction around only the write ("Good").}}

> Severity for plan review: **WARN**.
