# No `DB` Facade

Application code does not use the `DB` facade for data access; Eloquent models, relationships, and scopes are the only read/write path. `DB::transaction(...)` is the one
permitted use.

`DB::table(...)` returns untyped `stdClass` rows: no casts, no accessors, no global scopes, and nothing static analysis can reason about. Every guarantee the model layer
provides — tenant scoping, soft deletes, model events, observers — is silently skipped. `DB::transaction(...)` is different: it wraps work in a transaction without
bypassing anything, so it stays available and is the correct tool for an atomic multi-write.

**Rules:**

- No `DB::table`, `DB::select`, `DB::insert`, `DB::update`, `DB::delete`, `DB::statement`, `DB::scalar`, `DB::cursor`, or `DB()` helper in application or module code.
- `DB::transaction(fn () => ...)` is permitted and is the correct wrapper for an atomic multi-row write. See
  [Cache Lock over `lockForUpdate`](./cache-lock-over-lockforupdate.md) for why it is not a concurrency guard.
- Bulk operations use Eloquent's own bulk paths (`Model::query()->upsert(...)`, `->insert(...)`, chunked writes), not the facade.
- Use `belongsToMany` operations or a dedicated Pivot/Eloquent model for pivot rows, never `DB::table('..._pivot')`.
- A table without a model needs a model; the `DB` facade is not an escape hatch.
- Schema migrations use the Schema builder. Data migrations use Eloquent, never a `DB` call in a migration.

**Example:**

```php
// Bad — untyped rows, no casts, no global scopes, no model events
$rows = DB::table('invoices')->where('status', 'open')->get();

// Good — Eloquent keeps casts, scopes, and events intact
$invoices = Invoice::query()->where('status', InvoiceStatus::Open)->get();
```

> Severity for plan review: **BLOCK**.
