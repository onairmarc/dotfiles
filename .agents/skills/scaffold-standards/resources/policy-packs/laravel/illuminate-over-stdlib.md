# Illuminate Helpers over PHP Primitives

When Illuminate ships an equivalent for a PHP standard-library function, the Illuminate helper is **always** used — `Str`, `Arr`, `Number`, `Collection`, and the
framework's service facades come before `preg_*`, `str_*`, `array_*`, and their siblings. This holds for applications and for in-repo packages alike: a package that
depends on `illuminate/support` has the helpers available and is held to the same rule.

This is the Laravel reading of [Dependencies](./dependencies.md): "prefer what is already available" ranks the framework *above* the raw language, because in a Laravel
application the framework is not a dependency to be justified — it is the platform. The helpers are not sugar. `Str::slug()` is Unicode-aware where a hand-rolled
`preg_replace` chain is not; `Arr::get()` returns a default instead of emitting a notice on a missing nested key; `Number::format()` respects the application locale where
`number_format()` hard-codes English separators; `Str::contains()` takes an array of needles where `str_contains()` takes one and invites a chain of `||`. Each raw call
is a small re-implementation of something already written, tested across every supported PHP version, and readable at a glance by anyone who knows the framework.

The specific case that recurs: a `preg_replace` or `preg_match` written to do something `Str` already names. A regex is write-once, read-never — the next reader has to
execute the pattern in their head to learn the intent, where `Str::slug($title)` or `Str::squish($input)` says it outright.

**Rules:**

- Prefer the Illuminate helper whenever one exists for the operation. `Str::replace`, `Str::replaceMatches`, `Str::contains`, `Str::startsWith`, `Str::endsWith`,
  `Str::before`, `Str::after`, `Str::limit`, `Str::squish`, `Str::mask`, `Str::slug`, `Str::camel`, `Str::snake`, `Str::headline`, `Str::padLeft`, `Str::random`,
  `Str::uuid`, and `Str::orderedUuid` all replace a `preg_*`, `str_*`, `substr`, `sprintf`, or `uniqid` call.
- **Reach for `Str` before writing a regex.** A `preg_replace`, `preg_match`, or `preg_split` that reproduces a named `Str` operation is rejected. When the pattern is
  genuinely bespoke, use `Str::replaceMatches` / `Str::of(...)->match()` / `->matchAll()` / `->isMatch()` so the call still reads as string work rather than as PCRE.
- Array work goes through `Arr` or a `Collection`: `Arr::get` / `Arr::set` / `Arr::has` for nested access instead of `isset` chains, and `Arr::first`, `Arr::last`,
  `Arr::pluck`, `Arr::only`, `Arr::except`, `Arr::where`, `Arr::flatten`, `Arr::wrap` in place of `array_column`, `array_filter`, `array_intersect_key`, and friends.
- A chain of two or more `array_map` / `array_filter` / `usort` calls becomes a `collect(...)` pipeline. One pipeline reads top to bottom; nested array functions read
  inside out.
- Number formatting for display goes through `Number` (`format`, `currency`, `percentage`, `abbreviate`, `fileSize`, `ordinal`), never `number_format` or a hand-built
  `sprintf`, so the application locale is honored.
- Date and time work uses the framework's Carbon types, never `strtotime`, `date`, `mktime`, or a bare `DateTime` — see
  [CarbonImmutable Only](./carbon-immutable-only.md).
- I/O and transport go through the framework's facades — `Http` rather than `curl_*` or `file_get_contents` against a URL, `Storage` rather than `fopen` /
  `file_put_contents`, `Hash` rather than `password_hash` — so configuration, retries, faking in tests, and disk abstraction all keep working.
- **This rule is about which already-available API to call. It is not a license to add a package.** Adding a third-party dependency still has to clear
  [Dependencies](./dependencies.md).
- The rule applies equally in application code and in this repo's own packages. A package requiring `illuminate/support` has `Str`, `Arr`, `Number`, and `Collection`
  available; "it's only a package" is not a reason to drop to raw PHP.
- Raw PHP is correct in exactly one case: Illuminate has no equivalent for the operation. A binary-safety or encoding requirement that only a specific `mb_*` or `iconv`
  function satisfies counts as no equivalent. Performance is **not** a reason — these helpers are thin, and a hand-rolled replacement needs a profile in the pull request
  proving the difference is real and load-bearing.
- {{GEN:confirm against the Laravel version in this project's `composer.json` which of the helper classes named above are available — `Illuminate\Support\Number` in
  particular arrived after `Str` and `Arr` — and drop any bullet naming a class the installed version does not ship. Detect the version from the lockfile.}}

**Example:**

```php
// Bad — a regex reimplementing Str::slug, an isset chain, and locale-blind formatting
$slug = strtolower(trim(preg_replace('/[^A-Za-z0-9-]+/', '-', $title), '-'));
$region = isset($payload['billing']['address']['region'])
    ? $payload['billing']['address']['region']
    : 'unknown';
$total = '$' . number_format($invoice->total / 100, 2);

// Good — the intent is the method name
$slug = Str::slug($title);
$region = Arr::get($payload, 'billing.address.region', 'unknown');
$total = Number::currency($invoice->total / 100);
```

```php
// Bad — nested array functions, read inside out
$names = array_values(array_unique(array_map(
    fn (array $row): string => trim($row['name']),
    array_filter($rows, fn (array $row): bool => $row['active']),
)));

// Good — one pipeline, read top to bottom
$names = collect($rows)
    ->where('active')
    ->map(fn (array $row): string => trim($row['name']))
    ->unique()
    ->values()
    ->all();
```

> Severity for plan review: **WARN**.
