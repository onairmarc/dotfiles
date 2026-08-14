# Data Access

Persistent data is read and written through the project's data-access layer — its query builder, repositories, and mapped models — never through hand-written query
strings embedded in application code.

A raw query string bypasses everything the data-access layer guarantees: type mapping, soft-delete and scoping filters, connection routing, and the checks static analysis
can perform. It is also invisible to the type checker, so its result is an untyped bag that callers unwrap with unchecked accessors. Expressing the same intent through
the layer keeps the guarantees intact and keeps the code analyzable.

**Rules:**

- {{GEN:name this project's data-access layer (ORM, query builder, repository set) and the specific raw escape hatches that are banned in application code — the raw-SQL
  helpers, the low-level connection/facade calls, the string-executing methods. Detect from the manifest and confirm.}}
- {{GEN:state which low-level calls remain permitted and where — e.g. an explicit transaction wrapper, a documented migration or reporting path — so the ban has a precise
  edge. Ask the user for the exceptions this project actually needs.}}
- A calculation that genuinely cannot be expressed through the layer is done in application code over the fetched result set, for bounded result sets only — never by
  dropping to a raw string.
- Passing a qualified column or field identifier to a builder method is allowed; that is an identifier, not a raw query.
- Every query is scoped: no unbounded fetch of a growing table into memory. Paginate, filter, or aggregate at the source.

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a raw query string with an unchecked result ("Bad") with the same intent expressed through the data-access layer (
"Good").}}

> Severity for plan review: **BLOCK**.
