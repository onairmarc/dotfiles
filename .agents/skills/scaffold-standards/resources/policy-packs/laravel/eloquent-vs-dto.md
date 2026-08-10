# Eloquent vs DTO

In-process work passes Eloquent models and framework primitives; a DTO appears only where data leaves the process or must survive serialization. A DTO's shape is its list
of public typed properties, not a promoted-and-assigned constructor.

Wrapping an in-process call in a DTO adds a translation layer with no reader benefit — the model is already a typed object with the accessors and relationships the code
needs, and the caller and callee share one process and one deployment. At a serialization boundary the calculation flips: a queued payload must survive being written and
read back, and an external contract must not change because a column was renamed. A DTO is the written-down contract for exactly those crossings, and it reads best when
it is *only* the property list — a constructor that exists solely to promote and assign parameters is a second enumeration of every field in a fixed positional order,
which makes adding or reordering a property noisier than it should be.

**Rules:**

- In-process work passes Eloquent models, collections, and enums directly. Do not introduce a DTO for an in-process call, **including one that crosses a module
  boundary** — see [Module Isolation](./module-isolation.md#exported-contracts-boundary-types).
- A DTO is required at: an API request or response shape, a queued job payload, and an external integration client.
- A queued job takes a DTO or primitive scalars — never a serialized model whose state will be stale on retry.
- A DTO never carries a live model; map the fields it needs.
- A DTO's shape is its list of public typed properties. Do not write a constructor whose body only assigns its own promoted parameters to properties; keep or add a
  constructor **only** when its body does real work — normalization, derived defaults, invariant checks.
- {{GEN:name the DTO base type and namespace this project uses given {{MODULE_LAYOUT}}, and where boundary DTOs live within a module. Detect from the repo and confirm.}}

**Example:**

```php
// Bad — DTO ceremony for an in-process call, even though it crosses into another module
$billingService->recalculate(InvoiceData::from($invoice));

// Good — model for the in-process call...
$billingService->recalculate($invoice);

// ...DTO at the serialization boundary
SyncInvoiceToBilling::dispatch(InvoiceData::from($invoice));
```

> Severity for plan review: **WARN**.
