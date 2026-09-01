# Cache Lock over `lockForUpdate`

Distributed mutex and idempotency guards use `Cache::lock(...)->block(...)`; `lockForUpdate()` is reserved for the narrow case of an atomic multi-row write inside a
single transaction.

`lockForUpdate()` ties the mutex lifetime to a database transaction, so a queue worker holds an open connection for the entire critical section. On a busy fleet the
connection pool exhausts quickly and throughput collapses. A cache lock is cheap, observable, and decouples the mutex from the storage write. Transactions still wrap the
actual write for atomicity; the concurrency guard is a separate layer above it.

**Rules:**

- Concurrency guards: `Cache::lock("scope:{$id}", $ttlSeconds)->block($waitSeconds, fn () => ...)`.
- Lock keys are scoped to the entity (`invoice:charge:{$id}`, not `charge`) so unrelated entities do not contend. New keys
  follow [Cache Key Naming](./cache-key-naming.md).
- Atomic multi-row writes that must succeed-or-rollback together are wrapped in `DB::transaction(...)` — the right tool for atomicity, not for concurrency.
- Do not combine `lockForUpdate()` with `Cache::lock()` on the same critical section; pick one, almost always the cache lock.
- Never hold a lock across an unbounded external call; keep the TTL above the call's own timeout and make the work idempotent regardless.

**Example:**

```php
// Bad — holds the DB connection for the duration of a slow HTTP call
DB::transaction(function () use ($invoice) {
    $invoice->lockForUpdate();
    Http::post('https://billing.example/charge', ['amount' => $invoice->total]);
    $invoice->update(['status' => InvoiceStatus::Paid]);
});

// Good — cache lock for concurrency, transaction only around the write
Cache::lock("invoice:charge:{$invoice->id}", 60)->block(10, function () use ($invoice) {
    $charge = Http::post('https://billing.example/charge', ['amount' => $invoice->total])->throw()->json();
    DB::transaction(fn () => $invoice->update(['status' => InvoiceStatus::Paid, 'charge_id' => $charge['id']]));
});
```

> Severity for plan review: **WARN**.
