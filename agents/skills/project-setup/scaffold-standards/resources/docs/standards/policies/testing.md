# Testing

Every behavioral change ships with **{{TEST_FRAMEWORK}}** coverage, and assertions target what the system promises rather than how the current implementation words it.

Tests that pin down an exact validation message, an exact log string, or an exact query break on harmless refactors and teach both humans and agents to write brittle
code. A test that asserts the contract — the record persisted, the response issued, the job dispatched — survives refactors and fails only when behavior actually
regresses. Bug fixes start with a failing test because that is the only proof the fix addresses the reported behavior.

**Rules:**

- Every behavioral change ships tests. A bug fix starts with a failing test that reproduces the bug.
- The suite runs with `{{TEST_COMMAND}}` and must be green before a change merges.
- Follow the idioms of **{{TEST_FRAMEWORK}}**; do not invent a parallel test style alongside it.
- **Never skip, mark pending, or delete a failing test to reach green.** Fix the code, or fix the expectation with a stated reason. A skipped test is a hidden regression.
- Assert what the system promises, not how the implementation phrases it. One test, one behavior — a single failing assertion should name the broken behavior without a
  debugger.
- Fix pre-existing failures you encounter; the build blocks on them regardless of who introduced them.
- Do not put per-test cost back into the suite. Follow [Test suite performance](./test-suite-performance.md) when adding tests, factories, suite-level fakes, or runner
  pins.
- {{GEN:where tests live given {{MODULE_LAYOUT}}, the test-file naming convention for {{TEST_FRAMEWORK}}, how to run a scoped subset, the project's coverage expectation,
  and any shared fixture an author must know about (a global test context, a seeded tenant/account, a container the suite boots). Detect from the repo; ask the user for
  the coverage bar and the fixture semantics if they cannot be detected. Name the runner's collected paths so an uncollected file is not added. If `pest-conventions.md`
  was written, point at it for Pest `test()` / `describe()` / dataset rules.}}

**Example:**

{{GEN:a short {{TEST_FRAMEWORK}} snippet contrasting a test that pins an implementation-wording detail ("Bad") with one that asserts the contract the entry point promises
("Good").}}

> Severity for plan review: **BLOCK**.
