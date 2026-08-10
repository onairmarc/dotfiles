# Strong Typing

Everything is strongly typed: parameters, return values, and the data passed between functions, methods, and modules carry an explicit declared type — never an untyped
bag.

A loosely-keyed map moving a set of named fields around defeats every tool the project relies on: the type checker cannot verify the keys, the IDE cannot complete them,
and the reader cannot discover the shape without tracing the producer. Naming the shape once — as a class, struct, record, or the language's equivalent — turns every one
of those questions into a jump-to-definition.

**Rules:**

- **No loosely-keyed map as a data-transfer shape.** Do not pass or return an array/map/dict to move a set of named fields around. Model it with a typed structure so the
  shape is named, discoverable, and checked.
- **No bare strings for identity or dispatch.** A value drawn from a fixed set — a status, mode, kind, role — is an enum or union type. This reinforces
  [No Magic Values](./no-magic-values.md) at the type level.
- **Collections used as collections are fine.** An array, list, or map used *inside* a function for its real job — iteration, accumulation, lookup, a genuine homogeneous
  collection — is expected and permitted. The rule targets a map standing in for a *typed object*, not honest collection usage.
- Public surface carries the strictest type the language can express; do not widen a return type to avoid a cast at one call site.
- {{GEN:the concrete strong-typing mechanisms for {{PRIMARY_LANGUAGE}} — the record/struct/class construct used for parameter and return shapes, the enum/union construct
  used for fixed value sets, generic element typing for collections, and any type-checker settings the project relies on (strict mode, non-nullable references, declared
  element types). Author from the stack; ask the user for anything genuinely discretionary.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet contrasting a function that accepts and returns a loosely-keyed map ("Bad") with the same function typed against a named
structure and an enum ("Good").}}

> Severity for plan review: **BLOCK**.
