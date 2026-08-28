# Eloquent Factories Only

Test data is created exclusively through Eloquent factories and their named states; bespoke helpers, closures, and hand-assembled models in test files are forbidden.
Every model declares its factory explicitly with the `HasFactory` trait and a `#[UseFactory]` attribute.

A helper like `createUserWithRoles($email, ['admin'])` looks useful until a test needs a manager role too — then the helper grows arms and legs, every test carries
different default state, and the rules of what a valid `User` looks like live in a dozen places. A factory keeps that contract in one file and lets a test declare only
the attribute it actually cares about.

**Rules:**

- Every model that appears in a test has a factory, and the model wires it up with **both** of these:
    - `use Illuminate\Database\Eloquent\Factories\HasFactory;` — the trait that supplies the static `Model::factory()` entry point. Without it there is no `factory()`
      method to call.
    - `#[UseFactory(SomeFactory::class)]` from `Illuminate\Database\Eloquent\Attributes\UseFactory` — the attribute that names the factory class explicitly.
- **Declare `#[UseFactory]` even when the naming convention would have found the factory anyway.** Laravel only *requires* the attribute when the factory is not at
  `Database\Factories\<Model>Factory`, but relying on that convention makes the link invisible: nothing in the model names the factory, so a reader cannot jump to it, a
  rename silently breaks resolution at runtime rather than at analysis time, and the convention does not hold at all for models living in modules with their own
  namespaces. The attribute costs one line and makes the binding explicit and navigable.
- Never use a `newFactory()` override to bind a model to its factory. It is the legacy form the attribute replaces, it hides the binding inside a method body, and it
  cannot be read without opening the model.
- {{GEN:confirm `Illuminate\Database\Eloquent\Attributes\UseFactory` exists in the Laravel version this project has installed — read the lockfile, then verify the class
  is present in `vendor/`. It is a recent addition. If the installed version does not ship it, replace the two `#[UseFactory]` rules above with a single rule requiring
  the `$model` property on the factory plus a `newFactory()` override, and say plainly that the attribute is adopted on upgrade. Do not write the attribute into the
  policy for a version that cannot use it.}}
- Tests prefer a named state (`User::factory()->admin()->create()`) over an attribute bag (`User::factory()->create(['role' => 'admin'])`).
- Factories create required relationships themselves via `for(...)` / `has(...)` / state methods. Tests wire relationships by hand only when the relationship is the
  subject of the test.
- Do not create wrapper helpers around factory calls. Shared test *logic* follows the test-helper-class rule; test *data* comes from factories.
- A test asserts against values it set explicitly, never against a factory's incidental default.
- Default a child-model FK to a closure that reuses an existing tenant row and only builds a parent when none exists. For a `BelongsToTenant` model the trait's global
  scope already tenant-constrains the query, so the closure is `fn (): mixed => Model::query()->value("id") ?? Model::factory()` — a manual `->where("tenant_id", ...)`
  on that model is forbidden. Do not memoize the reused id with `once()` or a static: `RefreshDatabase` rolls the row back and the memoized id goes stale. Explicit
  overrides on `create([...])` / `make([...])` still win. Do not apply `value("id")` reuse to both FKs of a pair factory with a uniqueness or self-pair guard — derive the
  dependent FK from the same parent, or pass both FKs at the call site.
- Do not call `Hash::make` on every password (or equivalent secret) factory create. Memoize one bcrypt string per worker process on a static property
  (`self::$password ??= Hash::make("password")`). The `hashed` cast stores a bcrypt string as-is, so this does not double-hash. A low `BCRYPT_ROUNDS` pin in phpunit.xml
  does not replace this memo.
- Do not call `Model::factory()->create()` or `createOne()` inside `definition()`. That writes discarded rows while building the attribute array. Return factory instances
  or closures; let `Factory::expandAttributes` persist nested parents only when the FK was not passed in.
- Use `CarbonImmutable::now()`, never `now()` or mutable `Carbon` ([CarbonImmutable Only](./carbon-immutable-only.md)).
- {{GEN:state where factories live given {{MODULE_LAYOUT}} — the root `database/factories/` tree and any per-module factory trees — and, for a module-scoped factory, the
  fully-qualified class name to put in `#[UseFactory(...)]` plus how that factory namespace is registered/autoloaded. Detect and confirm.}}

**Example:**

```php
// Bad — no HasFactory, binding hidden in a newFactory() override
class User extends Model
{
    protected static function newFactory()
    {
        return UserFactory::new();
    }
}

// Good — trait supplies factory(), attribute names the factory class
use Illuminate\Database\Eloquent\Attributes\UseFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Database\Factories\UserFactory;

#[UseFactory(UserFactory::class)]
class User extends Model
{
    use HasFactory;
}
```

```php
// Bad — bespoke helper hand-assembling a model
function makeAdminUser(string $email): User
{
    $user = new User();
    $user->email = $email;
    $user->role = 'admin';
    $user->save();

    return $user;
}

// Good — factory plus a named state
test('admin can view billing', function () {
    $admin = User::factory()->admin()->create();

    actingAs($admin)->get('/billing')->assertOk();
});
```

```php
// Bad — a new parent per child, and a create() while building the definition
"reporter_id" => User::factory(),
"ticket_id" => Ticket::factory()->createOne()->id,

// Good — reuse a tenant row; nested factory only when none exists; no create() in definition()
"reporter_id" => fn (): mixed => User::query()->value("id") ?? User::factory(),
"ticket_id" => fn (): mixed => Ticket::query()->value("id") ?? Ticket::factory(),
```

> Severity for plan review: **BLOCK**.
