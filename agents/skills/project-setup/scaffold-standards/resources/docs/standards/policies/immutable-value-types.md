# Immutable Value Types

Values that model a point in time, a quantity, or any other identity-free concept use the immutable variant of their type; the mutable variant is not used in new code.

A mutable value type lets `start.addDays(30)` silently change the very value another part of the request still holds. The resulting bugs are real, hard to reproduce, and
usually surface far from the mutation. The immutable variant makes the change explicit by forcing the caller to capture the new instance — the compiler or type checker
does the arguing instead of a reviewer.

**Rules:**

- {{GEN:name the mutable/immutable type pairs this project cares about in {{PRIMARY_LANGUAGE}} — most commonly the date/time type, plus any money, duration, or collection
  pair — and state which member of each pair is required. Detect from dependencies and confirm.}}
- Type-hint the immutable variant in signatures so the constraint travels with the contract, not just with the construction site.
- Construct through the immutable factory/constructor rather than converting a mutable instance at the end.
- Persistence and serialization mappings are configured to produce the immutable variant; the default mapping usually produces the mutable one and must be overridden.
- Existing mutable usage is grandfathered; convert it when the surrounding code is next edited.

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a method that mutates its argument in place ("Bad") with the immutable equivalent that returns a new value (
"Good").}}

> Severity for plan review: **WARN**.
