# No `final` or `readonly`

The `final` and `readonly` keywords are not applied by default in application or module code; a developer adds them deliberately when the type really is closed.

Both keywords aggressively constrain how a type can evolve. In a modular codebase it is common to subclass a base class or override a behavior to slot a new module into
an existing surface; sealing by default locks doors nobody meant to lock, and the cost lands on whoever needs the extension later. The exception is a genuinely sealed
value object or event, where the author has decided the type is closed and says so in that pull request.

**Rules:**

- New classes and properties default to neither `final` nor `readonly`.
- Do not add `final` or `readonly` "on principle" during an unrelated refactor.
- When an Artisan or Filament generator emits `final` by default, strip it before committing.
- Config classes in particular are not `readonly` — see [Typed Config Classes](./typed-config-classes.md).

> Severity for plan review: **WARN**.
