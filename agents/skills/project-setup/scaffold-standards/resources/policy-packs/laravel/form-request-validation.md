# Request validation

Every HTTP endpoint accepts user-supplied data through a dedicated Form Request. Controllers and component actions assume the input is already valid.

The boundary is the only place that knows the full rule set for an endpoint, including custom messages and authorization. Spreading rules across the controller, service,
and model creates separate contracts that drift. A Form Request gives each endpoint one named input contract while keeping `spatie/laravel-data` `Data` objects available
for cross-module and serialization contracts rather than HTTP input.

**Rules:**

- Every HTTP endpoint that accepts input type-hints a concrete subclass of `Illuminate\Foundation\Http\FormRequest` in its action signature.
- Never accept HTTP input through a `spatie/laravel-data` `Data` object. `Data` objects are for structured cross-module and serialization contracts.
- Controllers type-hint the Form Request. Never call `$request->validate(...)` or `Validator::make(...)` inline.
- A Form Request owns `rules()`, `authorize()`, and custom messages.
- Livewire components validate through `rules()` or `#[Validate]` attributes; the rules live in one place per component.
- Custom messages live beside the rules in the Form Request.
- Client-side validation is a UX convenience; the server remains authoritative and a `422` is the final word.
- {{GEN:name where Form Requests live given {{MODULE_LAYOUT}}, and how a controller maps validated input into the project's cross-module Data contracts. Detect and confirm.}}

**Example:**

```php
// Bad — inline rules in the controller
public function store(Request $request)
{
    $data = $request->validate(['name' => 'required|string|max:120']);

    return Customer::create($data);
}

// Good - Form Request owns the contract
public function store(StoreCustomerRequest $request)
{
    return new CustomerResource(Customer::create($request->validated()));
}
```

> Severity for plan review: **WARN**.
