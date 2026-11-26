# Eloquent, Form Requests, Resources, and DTOs

Within a module, in-process work passes Eloquent models and framework primitives. HTTP input enters through Form Requests, HTTP output leaves through API or JSON
Resources, and a DTO appears at structured cross-module and serialization boundaries. A DTO's shape is its list of public typed properties, not a
promoted-and-assigned constructor.

An Eloquent model belongs to its owning module and is not a stable external contract. A Form Request owns validation and authorization at the HTTP boundary; a Resource
owns the HTTP representation; and a DTO is the stable, typed contract for structured data another module, worker, or external consumer receives. Keeping those roles
separate prevents a column rename or validation rule change from silently changing a public contract. A DTO reads best when it is only the property list — a constructor
that exists solely to promote and assign parameters is a second enumeration of every field in a fixed positional order.

**Rules:**

- Within a module, in-process work passes Eloquent models, collections, and enums directly. Do not introduce a DTO solely for an internal call.
- Every HTTP endpoint accepts input through a concrete `FormRequest`. A DTO is never the HTTP request contract — see
  [Request validation](./form-request-validation.md).
- Every HTTP response that returns application data is represented by an `ApiResource` or `JsonResource`. A DTO is never returned as the HTTP response contract.
- Use a DTO for structured data crossing a module boundary, including public service arguments and returns, emitted events, and other published contracts. Primitive
  identifiers and enums may cross a boundary when they fully express the contract.
- Use a DTO at serialization boundaries: queued job payloads and external integration clients.
- A queued job takes a DTO or primitive scalars — never a serialized model whose state will be stale on retry.
- A DTO never carries a live Eloquent model; map the fields it needs.
- A DTO's shape is its list of public typed properties. Do not write a constructor whose body only assigns its own promoted parameters to properties; keep or add a
  constructor **only** when its body does real work — normalization, derived defaults, invariant checks.
- {{GEN:name the Form Request, API/JSON Resource, and DTO namespaces this project uses given {{MODULE_LAYOUT}}. State where each lives within a module and the DTO base
type. Detect and confirm.}}

**Example:**

```php
// Bad — Eloquent model crosses the Billing module boundary and becomes the HTTP response.
$invoice = $billingService->recalculate($invoice);

return $invoice;

// Good — the HTTP boundary receives a Form Request; the module boundary receives a DTO;
// the HTTP representation is a Resource.
public function store(StoreInvoiceRequest $request, BillingService $billing): InvoiceResource
{
    $invoice = $billing->recalculate(InvoiceData::from($request->validated()));

    return new InvoiceResource($invoice);
}
```

> Severity for plan review: **WARN**.
