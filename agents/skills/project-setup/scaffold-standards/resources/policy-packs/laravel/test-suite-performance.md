# Test suite performance

Do not put per-test cost back into the Pest suite. Seed shared fixtures once per worker via `TestCase::$seeder`, fake unused side effects in `tests/Pest.php`, reuse
factory parents, and keep pure-PHP tests off `RefreshDatabase`.

A test that re-runs a large Artisan seed, bcrypts a fresh password, boots Filament for a model assertion, or creates hundreds of rows with `->create()` in a loop pays
that cost on every worker, on every run, including CI. The fixtures, fakes, and phpunit.xml pins that cut that cost are the contract — not optional tuning. See
[Testing](./testing.md) for how the suite runs, [Pest Conventions](./pest-conventions.md) for `test()` / datasets,
and [Eloquent Factories Only](./eloquent-factories-only.md)
for parent reuse and password-hash memoization.

**Rules:**

- Do not re-create the shared test fixture inside a per-test `setUp` / `beforeEach`. Seed it once per worker with `protected string $seeder` on `Tests\TestCase`, which
  Laravel passes to `migrate:fresh --seeder` after migrate and **before** `beginDatabaseTransaction()`, inside the `$migrated` guard. Later tests on that worker roll back
  only their own writes.
- Do not override `afterRefreshingDatabase()` to seed. The installed `RefreshDatabase` trait runs that hook on **every** test, **after** the transaction has started, so
  the rows roll back with the test — the same cost as `setUp()`, no speedup.
- Do not add a `Queue::fake()`, `Notification::fake()`, cheap-vectorizer, or `activity()->disableLogging()` `beforeEach` in a test file whose directory `tests/Pest.php`
  already fakes. Opt back in from the test that needs the real behavior; do not add a second module-wide fake.
- Do not bind `uses(TestCase::class, RefreshDatabase::class)` to a file that never touches the database. Bind `uses(TestCase::class)` only for pure-PHP tests.
- Do not put model-only or date-logic tests in a file that boots a Filament panel or Livewire component. Split them into a sibling file whose `beforeEach` does not call
  `actingAs` or `Filament::setCurrentPanel`.
- Do not call `artisan view:clear` (or any command that wipes a cache shared by parallel workers) from a test.
- Do not persist thousands of rows when the assertion is "the command ran N times". A `creating` hook that returns `false` and counts attempts is the pattern for
  `Action::dispatch()` loops. `Event::fake()` does not skip those inserts: `FooImported::dispatch()` is `Action::dispatch()` → `handle()`, and `handle()` writes the row.
- Do not loop `Model::factory()->create()` for 50 or more rows whose assertions are a count or shape. Build attribute arrays with `factory()->make(...)` and
  `Model::query()->insert(...)`. `insert()` skips model events, so put `created_at`, `updated_at`, and `tenant_id` on the made rows. Stay on Eloquent — never the `DB`
  facade ([No `DB` Facade](./no-db-facade.md)).
- Do not add a test file the runner does not collect. An uncollected file is dead code.
- Do not remove or bypass the phpunit.xml `<env>` pins that keep Pulse, log files, broadcast daemons, and similar side effects off during a run. Do not point
  `APP_CONFIG_CACHE` / `APP_ROUTES_CACHE` at the shared `bootstrap/cache/config.php` or `bootstrap/cache/routes-v7.php` files a developer's `artisan serve` reads.
- Do not add `env()` calls outside `config/`. A cached test config bakes them as `null`.
- Factory parent reuse, password-hash memoization, and lazy `definition()` defaults are part of this contract —
  see [Eloquent Factories Only](./eloquent-factories-only.md).
- Near-duplicate tests that each boot HTTP or Livewire belong in one dataset-driven test — see [Pest Conventions](./pest-conventions.md). Merge only when every assertion
  in the source survives in the destination.
- {{GEN:name this project's `$seeder` class (or say the project has none yet and `$seeder` is the required hook for anything added), the `tests/Pest.php` fake bindings
  and how a test opts back in, the phpunit.xml testsuites and `<env>` pins, and any test-only cache paths under `bootstrap/cache/`. Detect from `tests/TestCase.php`,
  `tests/Pest.php`, and `phpunit.xml`; confirm with the user.}}

**Example:**

```php
// Bad — hundreds of bcrypts, users, and statuses, one model each
Ticket::factory()->count(501)->create(["title" => "corpus row"]);

// Good — reuse parent FKs (factory closures) and one insert
$now = CarbonImmutable::now();
$rows = Ticket::factory()->count(501)->make(["title" => "corpus row"])
    ->map(fn (Ticket $ticket): array => [
        ...$ticket->getAttributes(),
        "created_at" => $now,
        "updated_at" => $now,
    ])
    ->all();
Ticket::query()->insert($rows);
```

```php
// Bad — Filament panel boot paid by every model/date assertion in the file
beforeEach(function (): void {
    $this->actingAs($user);
    Filament::setCurrentPanel($panel);
});

test('fiscal year start is 1 January', function (): void {
    expect(FiscalYear::query()->first()->start_date->month)->toBe(1);
});

// Good — model tests in a sibling file with no panel boot; Livewire tests keep the panel file
```

> Severity for plan review: **BLOCK**.
