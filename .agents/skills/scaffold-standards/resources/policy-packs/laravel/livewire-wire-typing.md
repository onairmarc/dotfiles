# Wire Interface Typing

The JavaScript-visible surface of a Livewire component is typed from PHP: a component declares which properties and methods the front end may call, and the TypeScript
types are generated from that declaration rather than hand-written.

`$wire` is dynamic, so a front end calling a renamed method fails silently at runtime — in production, for one user, with no build-time signal. Declaring the exposed
surface in PHP and generating the types from it turns that failure into a type error at build time. It also documents the contract in the only place that can enforce it:
next to the code that serves it.

**Rules:**

- A component's JS-callable properties and methods are explicitly marked as exposed; nothing else is called from the front end.
- TypeScript types for `$wire` are generated from those declarations and committed. Never hand-edit the generated artifact.
- Renaming or removing an exposed member is a contract change: regenerate the types and update the callers in the same change.
- Front-end code accesses `$wire` through the generated type, never through an untyped cast.
- {{GEN:name the exposure attribute/mechanism, the generation command, and the committed generated artifact path this project uses. Detect and confirm.}}
- {{GEN:if part of this project's front end is not Livewire-driven (e.g. an Inertia + React surface), state which surfaces this policy covers and which follow their own
  contract instead. Ask the user; omit this bullet if the whole front end is Livewire.}}

**Example:**

```php
// Bad — front end calls a method nothing declares as public surface; a rename breaks it silently
public function refreshTotals(): void { /* ... */ }
```

```ts
// Bad
(window as any).Livewire.find(id).refreshTotals()

// Good — generated type; a rename is a build error
wire.refreshTotals()
```

> Severity for plan review: **BLOCK**.
