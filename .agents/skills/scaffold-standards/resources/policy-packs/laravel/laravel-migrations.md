# Migrations

Migrations are reversible and are never re-edited after they merge.

Editing an already-merged migration is a silent contract change: anyone with a fresh database gets a different schema than anyone who migrated up before the edit, and
nothing detects the divergence. Laravel's column modification is also subtractive — a `->change()` that omits an attribute drops it — so a partial restatement quietly
loses a default, a length, or a nullable flag.

**Rules:**

- Use `php artisan make:migration <name>` for every schema change; no manual schema edits in any environment.
- Every migration implements a working `down()` — the test is whether `php artisan migrate:rollback` returns the schema to its prior state.
- Never edit a committed migration to change a column type, add a column, or drop one. Write a new migration.
- When modifying a column, the new migration must restate **all** existing attributes on that column — length, nullable, default, comment — because Laravel drops anything
  omitted.
- A data backfill is its own migration, separate from the shape change, so either can be re-run or rolled back independently.
- {{GEN:state where migrations live for this project given {{MODULE_LAYOUT}} — a single `database/migrations/` tree, or per-module migration directories — detected from
  the repo.}}

**Example:**

```php
// Bad — partial restatement drops the default and the nullable flag
Schema::table('invoices', function (Blueprint $table) {
    $table->string('status')->change();
});

// Good — every attribute restated
Schema::table('invoices', function (Blueprint $table) {
    $table->string('status', 32)->nullable()->default('draft')->change();
});
```

> Severity for plan review: **WARN**.
