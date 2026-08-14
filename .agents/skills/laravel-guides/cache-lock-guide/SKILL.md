---
name: cache-lock-guide
description: Apply this skill when implementing concurrency guards, mutex patterns, idempotency checks, or duplicate-operation prevention — such as preventing double-submissions, race conditions on model state transitions, or any situation where lockForUpdate() might otherwise be used.
disable-model-invocation: false
allowed-tools: []
model: haiku
---

## Cache Lock Rule

Prefer `Cache::lock()` over `lockForUpdate()` for distributed mutex and idempotency guards.

DB transactions are still appropriate for atomicity of writes, but the concurrency guard itself should be a cache lock.

**Correct pattern:**

```php
Cache::lock("resource.{$this->id}.action", ttl: 10)->block(5, function (): void {
    DB::transaction(function (): void {
        // re-check state inside the transaction
        // perform atomic writes
    });
});
```

**Do not use:**

```php
Model::where('id', $this->id)->lockForUpdate()->first(); // ❌ prefer Cache::lock
```

**Common lock key conventions used in this codebase:**

- `"article.{$id}.submit-for-approval"` — prevent concurrent approval submissions
- `"approval-workflow.{$id}.review"` — prevent concurrent approve/reject

Use `->block($seconds, $callback)` to wait for the lock. If the lock cannot be acquired within the timeout, Laravel
throws a `LockTimeoutException`.