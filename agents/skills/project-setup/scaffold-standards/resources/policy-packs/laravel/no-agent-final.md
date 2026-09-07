# No agent-added `final`; use `readonly` for immutable state

Agents do not add `final` to application or module code. Use `readonly` deliberately when a property's or class's state is immutable; human developers may add `final`
when they decide a type is closed.

`final` closes an extension point and can constrain later module work, so only a human developer makes that product and architecture decision. `readonly` protects an
invariant without closing the type's extension surface, so it is the right default when state must not change after construction.

**Rules:**

- Agents do not add `final`, including when an Artisan or Filament generator emits it by default. Remove generator-added `final` before committing.
- A human developer may add `final` when they deliberately close a type and own the consequences for its consumers.
- Use `readonly` properties or classes when values must not change after construction, especially for value objects, request data, and explicit invariants.
- Do not add `readonly` during an unrelated refactor without an immutability reason.
- {{GEN:name any classes that must remain mutable because the framework hydrates or mutates them. Omit this bullet when the project has no such exception.}}

> Severity for plan review: **WARN**.
