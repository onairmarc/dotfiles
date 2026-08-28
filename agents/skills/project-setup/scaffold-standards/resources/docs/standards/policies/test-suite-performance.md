# Test suite performance

Do not put per-test cost back into the suite. Seed shared fixtures once per worker, fake unused side effects at the suite binding, reuse factory parents, and keep
pure-logic tests off the database-reset harness.

A test that re-seeds a large graph, hashes a fresh secret, boots the UI framework for a model assertion, or creates hundreds of rows in a loop pays that cost on every
worker, on every run, including CI. The fixtures, fakes, and runner pins that cut that cost are the contract — not optional tuning. See [Testing](./testing.md) for how
the suite runs, and [Test Data Factories](./test-data-factories.md) for parent reuse and expensive-hash memoization.

**Rules:**

- Do not re-create the shared test fixture (tenant, account, role graph, or equivalent) inside a per-test setup. Seed it once per worker, before the per-test transaction
  or equivalent rollback boundary, so later tests on that worker keep the rows.
- Do not seed from a hook that runs *inside* the per-test rollback. Rows created there roll back with the test, so the next test pays the cost again.
- Do not add a per-file fake for a side effect the suite already fakes at the directory binding (queue, mail, notifications, activity log, search indexer). Opt back in
  from the test that needs the real behavior; do not add a second suite-wide fake.
- Do not bind the database-reset harness to a file that never touches the database. Bind the light test-case only for pure-logic tests.
- Do not put model-only or date-logic tests in a file that boots a UI panel, component harness, or HTTP kernel those tests do not use. Split them into a sibling file
  whose setup does not authenticate or register a panel.
- Do not run a command from a test that wipes a cache shared by parallel workers (compiled views, config, routes).
- Do not persist thousands of rows when the assertion is "the command ran N times". Cancel persistence with a creating/inserting hook that returns false and counts
  attempts. A dispatcher fake does not skip work that runs inline on `dispatch()`.
- Do not loop factory `create()` for 50 or more rows whose assertions are a count or shape. Build attribute sets with `make` (or the stack's equivalent) and bulk-insert
  through the project's data-access layer. Bulk insert skips model events, so put timestamps and tenant/owner columns on the made rows.
- Do not add a test file the runner does not collect. An uncollected file is dead code.
- Do not remove or bypass the test-runner environment pins that keep Pulse, log files, broadcast daemons, and similar side effects off during a run. Do not point
  test-only config or route caches at the files a local `serve` process reads.
- Factory parent reuse, expensive-hash memoization, and lazy factory defaults are part of this contract — see [Test Data Factories](./test-data-factories.md).
- Near-duplicate tests that each boot HTTP or a UI harness belong in one dataset-driven test. Merge only when every assertion in the source survives in the destination.
- {{GEN:name this project's once-per-worker seed hook (TestCase `$seeder`, a worker-level fixture, a transaction that starts after migrate), the suite-level fake binding
  file, the runner config that lists collected test paths and env pins, and any test-only cache paths. Detect from phpunit.xml / pest.php / the base TestCase / the
  equivalent; confirm with the user. If the project has no shared fixture or no suite-level fakes, say so plainly and keep the rules above as the bar for anything added
  later.}}

**Example:**

{{GEN:a short {{TEST_FRAMEWORK}} snippet contrasting a loop of factory `create()` for hundreds of rows ("Bad") with a `make` plus bulk insert through the project's
data-access layer ("Good"). Name the real model and insert API this project uses.}}

> Severity for plan review: **BLOCK**.
