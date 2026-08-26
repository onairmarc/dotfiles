# CarbonImmutable Only

Date and time work uses `Carbon\CarbonImmutable`; mutable `Carbon\Carbon` is not used in new code.

Mutable Carbon instances allow `$start->addDay()` to silently mutate the very value another part of the request still holds. The resulting bugs are real, hard to
reproduce, and usually surface far from the mutation. `CarbonImmutable` makes the change explicit by forcing the caller to capture the new instance. Laravel accepts
either type, so the cost of switching is purely keystrokes.

**Rules:**

- Type-hint `CarbonImmutable` rather than `Carbon` in method signatures.
- Construct with `CarbonImmutable::now()`, `CarbonImmutable::parse(...)`, or `now()->toImmutable()`.
- Eloquent date casts use `'immutable_datetime'` / `'immutable_date'`. The default `'datetime'` cast returns mutable `Carbon` and must be replaced when adding a cast.
- Existing mutable usage is grandfathered; convert it when the surrounding code is next edited.

**Example:**

```php
// Bad — mutates $start in place
public function billingWindow(Carbon $start): Carbon
{
    return $start->addDays(30);
}

// Good — returns a new instance, $start untouched
public function billingWindow(CarbonImmutable $start): CarbonImmutable
{
    return $start->addDays(30);
}
```

> Severity for plan review: **WARN**.
