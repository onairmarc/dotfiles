# Pest Conventions

Tests are written in Pest with `test('description', ...)` — never `it(...)` — grouped in `describe()` blocks, and run with the flags this project standardizes on.

`test()` and `it()` are interchangeable to Pest, but mixing them makes the report harder to scan and makes copy-paste between files awkward. Picking one costs nothing and
buys consistency. The run flags matter for the same reason: if CI runs the suite one way and a developer runs it another, a change can pass locally under different timing
and isolation assumptions than the ones CI enforces.

**Rules:**

- `test('does the thing', fn () => ...)` — not `it(...)`. PHPUnit-style test classes are not added to new code.
- Group related cases with `describe('subject', function () { ... })`.
- Use Pest datasets (`->with([...])`) for repeated-input cases rather than copy-pasted bodies. A near-duplicate test that pays a full HTTP or Livewire boot belongs in one
  dataset-driven test. Merge or delete a source test only when every assertion it currently makes survives in the destination. Keep tests separate when the fixture or
  behavior is actually different. See [Test suite performance](./test-suite-performance.md).
- Prefer intention-revealing assertions (`assertForbidden()`, `assertNotFound()`) over raw status codes.
- Create tests with `php artisan make:test --pest <name>` and move the file into the correct tests tree before committing.
- {{GEN:state the exact suite invocation this project standardizes on — including any flag such as `--parallel` that must always be present, the scoped-subset form, and
  the commands that are explicitly not used (e.g. `php artisan test`). Detect from CI and confirm with the user.}}
- {{GEN:state where tests live given {{MODULE_LAYOUT}} — the application-root `tests/` tree versus per-module `tests/Feature` and `tests/Unit` trees — and any shared
  fixture the base `TestCase` establishes that an author must not re-create. Detect and confirm.}}

**Example:**

```php
// Bad — it(), and pins the validator's current wording
it('rejects empty email', function () {
    $this->post('/users', ['email' => ''])
        ->assertSessionHasErrors(['email' => 'The email field is required.']);
});

// Good — test(), asserts the contract the endpoint promises
test('rejects empty email', function () {
    $this->post('/users', ['email' => ''])->assertSessionHasErrors('email');
    assertDatabaseMissing(User::class, ['email' => '']);
});
```

> Severity for plan review: **BLOCK**.
