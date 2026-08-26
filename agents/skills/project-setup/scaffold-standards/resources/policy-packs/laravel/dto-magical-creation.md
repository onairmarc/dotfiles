# DTO Construction via `::from()` (laravel-data Magical Creation Methods)

A new `spatie/laravel-data` DTO is constructed at the callsite with `SomeData::from($source)` — never an explicitly-named creation method (`SomeData::fromModel($model)`,
`SomeData::fromOrder($order)`). laravel-data dispatches `::from($payload)` to a static **magical creation method** whose parameter type accepts the payload, so a method
named `fromOrder(Order $order)` is invoked automatically by `SomeData::from($order)`. The named method is therefore how you *customize*
`::from()`, not an alternative to it — and a DTO whose properties already map to the source needs no such method at all.

The dispatch is in the package itself: `Spatie\LaravelData\Resolvers\DataFromSomethingResolver::createFromCustomCreationMethod()` scans the DTO's static methods and picks
the one whose parameter `accepts(...)` the payload. This is the same mechanism that lets `::from()` build a DTO from a `Request`, an array, or a model. Because the
callsite is always `::from()`, a reader never has to know whether a given DTO customizes construction — the customization is an implementation detail of the DTO, not of
its callers. This extends [DTO Class Properties Over Promoted Constructors](./dto-class-properties.md)'s "do not add a constructor to make `::from(...)` work" from
constructors to named creation methods: neither is written just to move data across; both are written only when the move needs real logic.

**Rules:**

- **Construct with `SomeData::from($source)` at every callsite.** Never call a named `from<Type>()` method directly (`SomeData::fromOrder($order)`) — call
  `::from($order)`
  and let laravel-data dispatch into it. Direct calls hide the dispatch convention and diverge from the rest of the codebase.
- **Add a `public static function from<Type>(<Type> $x): self` magical creation method only when the mapping needs real work** — enum unwrap, auth or service lookups,
  date/number formatting, a relation whose name differs from the property, or a derived/conditional (`Optional`) field. Dispatch is by the parameter's **type**, not the
  `from<Suffix>` name — name it after the payload type for readability.
- **Do not add a `from<Type>()` method — or any hand-written pass-through constructor — when the DTO's properties map 1:1 to the source's attributes.** Default `::from()`
  hydration, plus any `#[MapInputName(...)]` input mapper, already fills them. A pass-through method is redundant boilerplate and cuts against the "no ceremony" spirit of
  [DTO Class Properties](./dto-class-properties.md).
- **When a transformer (a `JsonResource`, or a service assembling a payload) derives its output from a DTO, build the DTO once and read its typed properties.**
  `$dto = SomeData::from($model);` then read `$dto->someProp` — one `::from()` per transformer, no second source→struct mapping alongside it. Assembling output from typed
  DTO property reads makes a renamed or removed DTO field a static-analysis failure, which is what closes the type drift the DTO exists to prevent (relevant whenever the
  DTO is also the generated-client-type source via `#[TypeScript]` — see [Eloquent vs DTO](./eloquent-vs-dto.md)).

**Example:**

```php
// Good — leaf DTO maps 1:1 to model columns: NO creation method. Default ::from() + the input mapper hydrate it.
#[MapInputName(SnakeCaseMapper::class)]
class ContactData extends Data
{
    public int $id;
    public string $name;
    public string $emailAddress;   // <- filled from `email_address` by SnakeCaseMapper
}

// Good — composite DTO needs real mapping (enum unwrap, formatting): a magical creation method carries it.
#[MapInputName(SnakeCaseMapper::class)]
class OrderData extends Data
{
    public int $id;
    public string $statusLabel;
    public string $totalDisplay;

    // Invoked automatically by OrderData::from($order) — never called directly.
    public static function fromOrder(Order $order): self
    {
        return new self(
            id: $order->id,
            statusLabel: $order->status->label(),                       // enum unwrap = real logic
            totalDisplay: Number::currency($order->total_cents / 100),  // formatting = real logic
        );
    }
}

// Good — transformer builds the DTO once with ::from(), then reads typed properties (drift guard).
class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $dto = OrderData::from($this->resource);   // dispatches into fromOrder()

        return [
            "id" => $dto->id,
            "status_label" => $dto->statusLabel,
            "total_display" => $dto->totalDisplay,
        ];
    }
}

// Bad — named method called directly, hiding the dispatch convention.
$dto = OrderData::fromOrder($this->resource);

// Bad — pass-through creation method on a 1:1 DTO; default ::from() already does this.
class ContactData extends Data
{
    public static function fromModel(Contact $contact): self
    {
        return new self(id: $contact->id, name: $contact->name, emailAddress: $contact->email_address);
    }
}
```

> Severity for plan review: **WARN**.