# Livewire public-property typing

Every public property on a Livewire component has an explicit type declaration. Public methods invoked from the browser declare typed parameters and return types.

Livewire public properties hydrate from browser input on every round trip. An untyped property accepts arbitrary request data and moves failures away from the boundary where
they can be understood. A typed public surface lets static analysis check the component state and makes its wire contract visible where it is defined.

**Rules:**

- Every public property declares an explicit scalar, nullable, enum, data-object, or Eloquent-model type. No public property is untyped.
- Type values drawn from a fixed set as backed enums, not bare strings.
- Keep validation on the typed property with `#[Validate]` or in one component-level `rules()` declaration. Do not validate ad hoc inside an action.
- Give a property that is not initialized in `mount()` a typed default or a nullable type and `null` default.
- Public methods invoked by `wire:click` or `wire:submit` declare typed parameters and an explicit return type.
- Document keyed public arrays with an array-shape PHPDoc and homogeneous lists with an element-type PHPDoc.

**Example:**

```php
// Bad - untyped state and validation buried in an action.
public $status;

// Good - a checked state boundary.
#[Validate('required')]
public ProfileStatus $status = ProfileStatus::Active;
```

> Severity for plan review: **BLOCK**.
