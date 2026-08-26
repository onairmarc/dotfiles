# Cache Key Naming

New cache keys — locks, remember-entries, puts, and forgets — follow one segment convention, and a fixed prefix that is written in more than one place is a named
constant.

Cache keys are scanned in the cache store, in logs, and in the project's metrics. A dotted key (`proj.merge-component.12.34`) and a colon key
(`proj:merge_component:12:34`) look like two families; mixed separators make it impossible to prefix-scan one module's locks or remember-entries. Fixing the convention
once means every new key reads the same way. Multi-word segments join with one join character, never a second separator style.

**Rules:**

- {{GEN:state the segment convention this project uses for new cache keys — the separator, the casing of each authored segment, and a worked example of a lock key and a
  remember-entry. Ask the user; this is a project decision. Recommend colon-separated `snake_case` segments (`module:resource:{$id}`) unless the repo already has a
  dominant convention.}}
- Scope the key to the entity it protects (`invoice:charge:{$id}`, not `charge`) so unrelated work does not contend. See
  [Concurrency Guards](./concurrency-guards.md).
- A fixed prefix written in more than one place is a named constant — see [No Magic Values](./no-magic-values.md).
- Existing keys in an older convention are grandfathered. Convert one only as part of a deliberate, coordinated rename of every reader and writer of that key — a lock or
  remember-entry that changes spelling mid-flight is a missed mutex or a stale hit.
- When forgetting a key another call site already wrote, use that existing string verbatim — do not "fix" a grandfathered key on the forget side only.
- {{GEN:name this project's cache API (`Cache::lock` / `Cache::remember`, a Redis client, etc.), any framework-owned key wrapper that must not be restyled (e.g. a
  tenant-prefix helper), and where a shared prefix constant would live given {{MODULE_LAYOUT}}. Detect and confirm.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting an inconsistently separated or hyphenated key ("Bad") with a key that follows the convention just stated ("Good").
Use the project's real cache API.}}

> Severity for plan review: **WARN**.
