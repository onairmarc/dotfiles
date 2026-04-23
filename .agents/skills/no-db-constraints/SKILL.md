---
name: no-db-constraints
description: Apply this skill when removing database-level foreign key constraints and unique constraints from a Laravel project, replacing them with application-level enforcement. Handles both plan files (direct edits) and application code (new drop migrations + model boot logic).
argument-hint: "<path-or-scope> [additional context]"
allowed-tools:
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
model: opus
---

# No DB Constraints Skill

You are a senior Laravel engineer. Your job is to remove database-level foreign key constraints and unique constraints
from a Laravel project and replace them with equivalent application-level enforcement.

**Core principle:** The database is a dumb store. Referential integrity and uniqueness are business rules — they belong
in the application, not the schema.

---

## The Rules (non-negotiable)

1. **No database-level foreign key constraints.** Remove all `->foreign()`, `->foreignId()` with constraint,
   `->constrained()`, and `FOREIGN KEY` references from migrations.
2. **No database-level unique constraints.** Remove all `->unique()`, `$table->unique([...])`, and `UNIQUE KEY`
   declarations from migrations.
3. **Indexes are fine.** A plain `->index()` or `$table->index([...])` is not a constraint — it is a performance
   tool. Keep them. Add them where they make sense (e.g., columns used in `WHERE`, `JOIN`, or `ORDER BY` that
   previously had a unique index can become a plain index).
4. **Never edit an existing migration to drop a constraint** when that migration has already run in production.
   Instead, create a **new** migration with `dropForeign()` / `dropUnique()` / `dropIndex()` + `->index()` where
   appropriate.
5. **Plan files are different.** A plan file describes future work that has not yet been executed. Edit plan files
   directly — do not create migrations for constraints that the plan was about to create but never did.
6. **Uniqueness checks live in the model's `boot()` method** using Eloquent lifecycle hooks (`creating`, `updating`).
   Place the check as close as possible to where the business rule is enforced.
7. **Uniqueness checks must be fast.** Use `->exists()` — never `->count() > 0`. The check excludes the current
   model instance (self) by filtering out its primary key when `$model->exists` is true.
8. **For complex or reused uniqueness rules**, create a dedicated `Rule` class in the appropriate `Rules/` directory
   that models can reference. Simple one-off rules stay inline in `boot()`.

---

## Pre-flight — Orient yourself

Before talking to the user, gather context:

1. **Detect target scope** from `$ARGUMENTS`. It may be:
    - A file path (single migration, model, or plan file)
    - A directory path (scan for violations within it)
    - Empty (scan the whole repo)

2. **Classify each in-scope file** as one of:
    - `plan` — a markdown plan file in a planning directory (`docs/_planning/`, `docs/planning/`, `planning/`,
      `_planning/`)
    - `migration` — a PHP file under `database/migrations/`
    - `model` — a PHP Eloquent model
    - `other` — anything else

3. **Scan for violations** in in-scope files:

| Violation                           | Pattern to grep                                                      |
|-------------------------------------|----------------------------------------------------------------------|
| FK via `->foreign()`                | `->foreign\(`                                                        |
| FK via `->constrained()`            | `->constrained\(`                                                    |
| FK via `foreignId()->constrained()` | `foreignId.*constrained`                                             |
| Unique constraint                   | `->unique\(`                                                         |
| Table-level unique                  | `\$table->unique\(`                                                  |
| Unique in plan text                 | `unique\(\)` or `UNIQUE` in `.md` files                              |
| FK in plan text                     | `foreign\(\)` or `->constrained\(\)` or `FOREIGN KEY` in `.md` files |

4. **For each migration violation**, determine if the migration has likely already run in production by checking
   whether a newer migration exists dated after it. Ask the user if unsure.

5. **Find the Eloquent model** for each migration table containing a violation. Search for a model class whose
   `$table` property or class name maps to the table.

6. **Detect existing `boot()` methods** in affected models to understand what's already there.

7. **Detect existing `Rules/` directories** to know where to place new rule classes.

---

## Step 0 — Confirm scope with user

Use `AskUserQuestion` to present findings and confirm scope. Ask in a single call:

> **Constraint audit — scope confirmation**
>
> Found the following violations:
>
> **Migrations with database-level constraints:**
> - [list each migration file and which constraint types: FK / unique]
>
> **Plan files with database-level constraints:**
> - [list each plan file and the relevant section]
>
> **Models to update:**
> - [list each model — or "none found yet, will determine per table"]
>
> Before I proceed, a few questions:
>
> 1. Are there **additional files or directories** I should include or exclude?
> 2. For the migrations listed above — are any of these **not yet run in production**? If so, I can edit them
     > directly instead of creating drop migrations. *(List which ones if any.)*
> 3. For uniqueness rules: are there any that need to be **reused across multiple models** or that involve
     > **complex cross-field logic**? Those become dedicated `Rule` classes. *(Describe them if so.)*
> 4. Are there any **existing application-level checks** already in place that I should be aware of to avoid
     > duplicating?

Adjust scope and approach based on the user's answers before proceeding.

---

## Step 1 — Process plan files

For each plan file containing constraint violations:

1. Read the file.
2. Find every reference to:
    - `->unique()` — replace with `->index()` if uniqueness on that column makes sense for query performance,
      otherwise remove entirely.
    - `->foreign()`, `->constrained()`, `foreignId()->constrained()`, `FOREIGN KEY` — remove the constraint
      declaration. If the column itself (e.g. `->foreignId('user_id')`) is being added, keep the column but
      change to `->unsignedBigInteger('user_id')` (or keep `->foreignId()` but without `->constrained()`).
    - `$table->unique([...])` — replace with `$table->index([...])` if indexing makes sense, otherwise remove.
3. For every removed unique constraint, add a note in the plan that uniqueness will be enforced in the model's
   `boot()` method.
4. For every removed FK constraint, add a note that referential integrity will be enforced in the model's
   `boot()` method or service layer.
5. If the plan step creates a migration, update the migration step to not include constraints. Add a new
   implementation step for adding the `boot()` logic to the appropriate model.
6. Edit the plan file directly using `Edit`. Do not create a new file.

---

## Step 2 — Process migrations (already-run)

For each migration that has already run in production and contains constraint violations:

### 2a — Create a drop migration

Create a new migration file dated after the most recent existing migration. Name it descriptively:

```
database/migrations/{timestamp}_drop_{table}_constraints.php
```

The migration must:

- Use `Schema::table()` to modify the existing table.
- Drop each FK constraint with `$table->dropForeign(['column_name'])`.
- Drop each unique constraint with `$table->dropUnique(['column_name'])` or
  `$table->dropUnique('{table}_{column}_unique')`.
- After dropping a unique constraint, add `$table->index(['column_name'])` **only if** a plain index on that
  column would benefit query performance (i.e., the column is used in lookups or joins). If the unique
  constraint was the only reason for the index and the column is not queried by value, omit the plain index.
- After dropping a FK constraint on a column (e.g. `user_id`), add `$table->index(['user_id'])` **unless** a
  plain index already exists on that column. FK columns are almost always used in joins — default to adding
  the plain index and only omit if you can confirm the column is never queried.
- Provide a `down()` method that restores the dropped constraints (for local rollback safety).

**Example — drop FK and unique, keep plain indexes:**

```php
public function up(): void
{
    Schema::table('orders', function (Blueprint $table): void {
        $table->dropForeign(['user_id']);
        $table->dropUnique(['email']);
        $table->index(['user_id']); // keep for join/lookup performance
        $table->index(['email']);   // keep for lookup performance
    });
}

public function down(): void
{
    Schema::table('orders', function (Blueprint $table): void {
        $table->dropIndex(['user_id']);
        $table->dropIndex(['email']);
        $table->unique(['email']);
        $table->foreign('user_id')->references('id')->on('users');
    });
}
```

### 2b — Do NOT edit the original migration

The original migration file must remain unchanged. Only create new migrations.

---

## Step 3 — Process migrations (not yet run)

For each migration confirmed by the user as **not yet run in production**:

1. Edit the migration file directly.
2. Remove FK constraint declarations (keep the column, remove `->constrained()` / `->foreign()`).
3. Replace `->unique()` with `->index()` where a plain index makes sense, otherwise remove.
4. Remove `$table->unique([...])` declarations (replace with `$table->index([...])` if appropriate).
5. Remove any `$table->foreign(...)` declarations.

---

## Step 4 — Add application-level uniqueness enforcement to models

For each table that had a unique constraint removed, find the corresponding Eloquent model and add enforcement
in its `boot()` method.

### Determining where the check goes

- **Simple, single-model rule** → inline in `boot()` using `creating` and `updating` hooks.
- **Complex rule** (multiple columns, cross-table logic, conditional uniqueness) → dedicated `Rule` class, then
  call it from `boot()`.
- **Rule reused in multiple models** → dedicated `Rule` class.

Ask the user via `AskUserQuestion` if you are unsure which category applies to a specific rule.

### Inline `boot()` pattern

```php
protected static function boot(): void
{
    parent::boot();

    static::creating(function (self $model): void {
        if (static::where('email', $model->email)->exists()) {
            throw \Illuminate\Validation\ValidationException::withMessages([
                'email' => 'The email has already been taken.',
            ]);
        }
    });

    static::updating(function (self $model): void {
        if (static::where('email', $model->email)
            ->where('id', '!=', $model->id)
            ->exists()) {
            throw \Illuminate\Validation\ValidationException::withMessages([
                'email' => 'The email has already been taken.',
            ]);
        }
    });
}
```

**Rules for the inline check:**

- Use `->exists()`, never `->count() > 0`.
- In `updating`: always exclude self by `->where('id', '!=', $model->id)` (or the model's primary key if
  different from `id`).
- In `creating`: no self-exclusion needed.
- Throw `\Illuminate\Validation\ValidationException::withMessages(['field' => 'message'])`. This renders as
  HTTP 422 and is caught by Laravel's exception handler — it surfaces as a validation error to the caller,
  not a 500. Only deviate if the project has an established alternative; check nearby model code first.
- If the model already has a `boot()` method, **add** the hooks to it — do not replace it.

### Composite unique constraint (multi-column)

```php
static::creating(function (self $model): void {
    if (static::where('user_id', $model->user_id)
        ->where('slug', $model->slug)
        ->exists()) {
        throw \Illuminate\Validation\ValidationException::withMessages([
            'slug' => 'The slug has already been taken for this user.',
        ]);
    }
});
```

### Dedicated Rule class pattern

Create the class in the model's module's `Rules/` directory (or `app/Rules/` if no module structure):

```php
<?php

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

final class UniqueEmail implements ValidationRule
{
    public function __construct(
        private readonly ?int $exceptId = null,
    ) {}

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        $query = \App\Models\User::where('email', $value);

        if ($this->exceptId !== null) {
            $query->where('id', '!=', $this->exceptId);
        }

        if ($query->exists()) {
            $fail("The :attribute has already been taken.");
        }
    }
}
```

Then call it from `boot()`:

```php
static::creating(function (self $model): void {
    validator(['email' => $model->email], [
        'email' => [new \App\Rules\UniqueEmail()],
    ])->validate();
});

static::updating(function (self $model): void {
    validator(['email' => $model->email], [
        'email' => [new \App\Rules\UniqueEmail(exceptId: $model->id)],
    ])->validate();
});
```

---

## Step 5 — Referential integrity (FK replacement)

Removed FK constraints do **not** automatically need a code replacement for every case. Use judgment:

| Scenario                          | Recommended approach                                       |
|-----------------------------------|------------------------------------------------------------|
| Hard delete cascade was the point | Add `deleting` hook in parent model to cascade or reject   |
| Soft delete orphan prevention     | Add `creating`/`updating` check that related record exists |
| Pure lookup (no cascade needed)   | No code needed — the FK was just a DB safety net           |
| Data integrity across services    | Service layer check, not model `boot()`                    |

Ask the user via `AskUserQuestion` for any FK whose purpose is unclear before deciding.

---

## Step 6 — Verify and present summary

After all changes are made, present:

```
## Done

**Plan files updated:** N
  - [list files]

**Drop migrations created:** N
  - [list migration files]

**Existing migrations edited:** N (not-yet-run only)
  - [list files]

**Models updated with boot() checks:** N
  - [list models and which columns/rules were added]

**Rule classes created:** N
  - [list class names and paths]

**Plain indexes added (replacing dropped unique indexes):** N
  - [list table + column]

**FK constraints removed (no app-level replacement needed):** N
  - [list — reason why no replacement was needed]
```

Then ask:

> All changes are in place. Would you like me to review anything specific, or are there additional files to process?

---

## Guidelines

- **Never add unique indexes** — if the user's instinct is "I need uniqueness on this column," redirect to `boot()`.
- **Never edit an already-run migration** — create a new one.
- **Never remove an index wholesale without considering performance** — replace unique indexes with plain indexes
  when the column is used in queries.
- **`->exists()` only** — `->count()` is banned for existence checks.
- **Self-exclusion in `updating`** — always. Forgetting this breaks updates on every existing record.
- **Check existing `boot()` first** — do not overwrite it.
- **Match the project's exception style** — inspect nearby model code before choosing an exception class.
- **Ask, don't assume** — for FK purpose, rule complexity, and production/not-yet-run status of migrations.