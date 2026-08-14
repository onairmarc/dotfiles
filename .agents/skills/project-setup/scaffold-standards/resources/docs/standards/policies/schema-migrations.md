# Schema Migrations

Schema changes ship as reversible migrations that are never re-edited after they merge.

Editing an already-merged migration is a silent contract change: anyone with a fresh database gets a different schema than anyone who migrated before the edit, and
nothing in the system detects the divergence. A migration without a working reverse step is a one-way door — the first failed deploy discovers it. Both problems are
solved by the same discipline: one migration per change, forward and back, appended rather than amended.

**Rules:**

- Every schema change is a migration created through the project's migration tooling; no manual schema edits in any environment.
- Every migration implements a working reverse step. The test is whether rolling back returns the schema to its prior state.
- Never edit a merged migration to change, add, or drop a column. Write a new migration.
- When modifying an existing column, restate every attribute it must keep — most tooling drops what the new definition omits.
- A migration that moves data is separate from one that changes shape, so either can be re-run or rolled back on its own.
- {{GEN:the project's migration tooling and command, where migration files live given {{MODULE_LAYOUT}}, and any project stance on database-level constraints, indexes, or
  zero-downtime sequencing. Detect and confirm.}}

**Example:**

{{GEN:a short migration snippet in this project's tooling contrasting an amended/irreversible migration ("Bad") with a new, reversible migration that restates the
column's full definition ("Good").}}

> Severity for plan review: **WARN**.
