# Authorization Identifier Naming

Permission and role identifiers follow one segment convention, and every identifier is declared as an enum member rather than written as a literal.

Authorization identifiers are parsed and grouped by their segments, so a consistent separator is what lets both tooling and humans read the hierarchy at a glance —
`email:connection:manage` says *the Email module's connection resource, manage action* without ambiguity. Codebases drift here faster than anywhere else, because each new
subsystem invents its own separator. Fixing the convention once means every new identifier reads the same way, and declaring identifiers as enum members means a rename is
a compile error rather than a grep.

**Rules:**

- {{GEN:state the segment convention this project uses — the separator, the casing of each segment, and the segment order (e.g. module, resource, action) — with a worked
  example. Ask the user; this is a project decision. Recommend colon-separated `snake_case` segments (`module:resource:action`) unless the repo already has a dominant
  convention.}}
- One separator and one segment casing across the identifier. Do not mix separators (`email.connection:manage`) or casings (`email:connectionManage`).
- Every identifier is declared as an enum member, never inlined as a literal — see [No Magic Values](./no-magic-values.md). Human-facing display text is free-form; only
  the stored value follows this convention.
- A permission is checked through the enum member, never by string comparison at the call site.
- Existing identifiers in an older convention are grandfathered. Renaming one is a coordinated change: a stored identifier is data, so it needs a matching data migration
  or re-seed, not just a code edit.
- {{GEN:name any grandfathered identifier family that must not be flipped piecemeal (panel-access strings, legacy dotted permissions) and where authorization identifier
  enums live given {{MODULE_LAYOUT}}, plus how a new one is registered with the authorization system. Detect and confirm.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting inconsistent, inline identifier literals ("Bad") with enum-declared identifiers following the convention (
"Good").}}

> Severity for plan review: **WARN**.
