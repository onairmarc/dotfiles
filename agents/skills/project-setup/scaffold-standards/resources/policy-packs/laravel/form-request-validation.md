# Request validation

User-supplied data is validated once at the request boundary. Controllers and component actions assume the input is already valid.

The boundary is the only place that knows the full rule set for an endpoint, including custom messages and authorization. Spreading rules across the controller, service,
and model creates separate contracts that drift. Laravel supports Form Requests for request-shaped input and, when `spatie/laravel-data` is installed, Data-as-request for
a payload modeled by a Data class.

**Rules:**

- Every HTTP endpoint that accepts input uses `Illuminate\Foundation\Http\FormRequest` or, when the payload is a `spatie/laravel-data` shape, Data-as-request.
- Controllers type-hint the boundary object in the action signature. Never call `$request->validate(...)` or `Validator::make(...)` inline.
- A Form Request owns `rules()`, `authorize()`, and custom messages.
- A Data-as-request class owns `rules()` and `withValidator()`. Keep authorization as `Gate::authorize(...)` at the top of the controller action; do not declare an
  `authorize()` method on the Data class unless the project deliberately adopts laravel-data's authorization pipe.
- Livewire components validate through `rules()` or `#[Validate]` attributes; the rules live in one place per component.
- Custom messages live beside the rules in the Form Request or Data class.
- Client-side validation is a UX convenience; the server remains authoritative and a `422` is the final word.
- {{GEN:when `spatie/laravel-data` is installed, name its configured request-validation strategy and whether Data-as-request has a project-specific authorization rule.
Otherwise, remove the Data-as-request rules above and state that Form Requests are the only HTTP boundary shape.}}

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
    return Customer::create($request->validated());
}
```

> Severity for plan review: **WARN**.
