# No Magic Values

A literal that names a domain concept — a status, type, role, channel, threshold, or duration — is declared once as an enum member or named constant, never written
inline.

A duplicated literal is a refactor hazard: the next person who renames `"pending"` to `"awaiting_review"` has to grep, and they will miss one. A bare `86400` in a
conditional tells the reader nothing about whether it is a cache lifetime or a billing window. Naming the value once gives it a definition site, a type, and a place for
the comment explaining why it is that number.

**Rules:**

- A status, type, role, channel, or kind is an enum member, not a string literal compared by equality.
- A fixed key (cache-key prefix, queue name, event name, header name) is a named constant with one definition site.
- A numeric literal that carries meaning (timeout, retry count, page size, threshold) is a named constant.
- Before adding a new enum or constant, search for an existing one — the value you need is often already named.
- {{GEN:where this project's shared enums and constants live, given {{MODULE_LAYOUT}}, and the naming convention for a new one. Detect from the repo layout and confirm.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting an inline domain string or magic number in a conditional ("Bad") with the same comparison against an enum member or
named constant ("Good").}}

> Severity for plan review: **WARN**.
