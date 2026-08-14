# DTO Class Properties Over Promoted Constructors

This is the `spatie/laravel-data` form of the property-shape rule in [Eloquent vs DTO](./eloquent-vs-dto.md): a `Data` subclass declares plain public typed class
properties rather than promoted constructor parameters. It applies to every **new** DTO; existing DTOs are grandfathered until next edited.

`spatie/laravel-data` hydrates a DTO from its public typed properties — it does not need a constructor to populate them, so the promoted constructor buys nothing here
that the property list does not already state. When the constructor exists only to promote-and-assign, it is a second enumeration of every field in a fixed positional
order, which makes adding or reordering a property noisier than it should be. A constructor earns its place only when its body does real work — normalization, derived
defaults, invariant checks — and promotion is fine in that case.

**Rules:**

- New `Data` subclasses declare public typed **class properties**, not promoted constructor parameters, when no constructor logic is needed.
- Rely on laravel-data's property hydration; do not add a constructor to make `::from(...)` work.
- Convert a grandfathered DTO opportunistically the next time you edit it — this is a new-DTO rule, not a mass-migration mandate.

**Example:**

```php
// Bad — empty-body constructor exists only to promote-and-assign
class ContactData extends Data
{
    public function __construct(
        public int $id,
        public string $name,
    ) {}
}

// Good — class properties; laravel-data hydrates them
class ContactData extends Data
{
    public int $id;
    public string $name;
}

// Good — constructor stays because its body does real work
class DateRangeData extends Data
{
    public CarbonImmutable $start;
    public CarbonImmutable $end;

    public function __construct(CarbonImmutable $start, CarbonImmutable $end)
    {
        $this->start = $start->min($end);
        $this->end = $start->max($end);
    }
}
```

> Severity for plan review: **WARN**.
