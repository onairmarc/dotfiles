# Form Request Validation

User-supplied data is validated at the request boundary via Form Requests; controllers and component actions assume the input is already valid.

The boundary is the only place that knows the full rule set for an endpoint, including its custom messages and its authorization check. Spreading rules across the
controller, the service, and the model means three places to update when the contract changes — and three places to forget. A Form Request also gives authorization a
natural home in `authorize()` and lets cross-field rules resolve services through the container.

**Rules:**

- Every HTTP endpoint that accepts input has a corresponding `Illuminate\Foundation\Http\FormRequest` subclass.
- Controllers type-hint the Form Request in the action signature — never call `$request->validate(...)` inline.
- Livewire components validate through `rules()` or `#[Validate]` attributes; the rules live in one place per component.
- Custom messages live in the same Form Request as the rules they belong to.
- Client-side validation is a UX convenience; the server remains authoritative and a `422` is the final word.
- {{GEN:any documented exception this project deliberately allows — e.g. endpoints whose request shape is a `spatie/laravel-data` object carrying its own static
  `rules(...)`. Ask the user; omit this bullet if there is none.}}

**Example:**

```php
// Bad — inline rules in the controller
public function store(Request $request)
{
    $data = $request->validate(['name' => 'required|string|max:120']);

    return Customer::create($data);
}

// Good — Form Request owns the contract
public function store(StoreCustomerRequest $request)
{
    return Customer::create($request->validated());
}
```

> Severity for plan review: **WARN**.
