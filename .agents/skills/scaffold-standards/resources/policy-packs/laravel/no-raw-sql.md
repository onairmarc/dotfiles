# No Raw SQL

Database access goes through the Eloquent query builder, relationships, scopes, and collection methods — never hand-written SQL fragments.

Raw SQL fragments bypass Eloquent's attribute casting, global scopes, and soft-delete handling; they are unportable across database engines; and they are invisible to
static analysis, which cannot type a raw column alias, so callers fall back to magic-property access that then trips its own findings. Expressing the same intent through
the builder keeps the scopes and casts intact and keeps the code analyzable.

**Rules:**

- No `selectRaw`, `whereRaw`, `havingRaw`, `orderByRaw`, `groupByRaw`, `DB::raw`, `DB::select`, or `DB::statement`, and no SQL string passed to a query method.
- A conditional aggregate is expressed as separate builder aggregates (`->sum()`, `->count()`) combined with a model scope — not a single `CASE WHEN` / `COALESCE` raw
  expression.
- When a calculation genuinely cannot be expressed in the builder, fetch the rows with Eloquent and compute in PHP over the resulting Collection, accepting the in-memory
  pass for bounded result sets only.
- Passing a table-qualified column name (`"tickets.assignee_id"`) to `where` / `groupBy` / `orderBy` is allowed — that is a column identifier, not raw SQL.

**Example:**

```php
// Bad — raw conditional aggregate: bypasses casts and global scopes, alias is unanalyzable
$row = $sprint->tickets()
    ->selectRaw("COALESCE(SUM(estimated_minutes), 0) as committed")
    ->selectRaw("COALESCE(SUM(CASE WHEN closed = 1 THEN estimated_minutes ELSE 0 END), 0) as closed")
    ->first();

// Good — Eloquent aggregates plus a model scope
$committed = (int) $sprint->tickets()->sum("estimated_minutes");
$closed = (int) $sprint->tickets()->statusClosed()->sum("estimated_minutes");
```

> Severity for plan review: **BLOCK**.
