# No Foreign Key Constraints

Migrations do not declare database-level foreign keys; referential integrity is enforced at the Eloquent layer.

A cross-module foreign key needs a single source of truth for the constraint definition, which forces one module's migration to know another module's table — exactly the
coupling [Module Isolation](./module-isolation.md) exists to prevent. Database-level cascades also fire outside the model layer, so observers, events, and audit trails
never see the deletion. Defining the relationship in Eloquent keeps enforcement where the domain rules already live.

**Rules:**

- No `->constrained()`, `->foreign(...)`, or raw `FOREIGN KEY` SQL in any migration.
- Declare the relationship on the model (`belongsTo`, `hasMany`) and rely on application-layer enforcement.
- Index the referencing column explicitly — dropping the constraint must not drop the index that made the join fast.
- Deletion cascades are expressed as model events or an explicit service call, never as `onDelete('cascade')`.

**Example:**

```php
// Bad — FK constraint at the DB level
Schema::create('invoices', function (Blueprint $table) {
    $table->id();
    $table->foreignId('tenant_id')->constrained();
});

// Good — relationship enforced in Eloquent, column still indexed
Schema::create('invoices', function (Blueprint $table) {
    $table->id();
    $table->unsignedBigInteger('tenant_id')->index();
});
```

> Severity for plan review: **BLOCK**.
