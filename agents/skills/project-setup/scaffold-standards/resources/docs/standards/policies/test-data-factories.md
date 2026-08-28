# Test Data Factories

Test data is created through the project's shared factory/builder surface with named states — never through bespoke per-file constructors that hand-assemble records.

A helper like `createUserWithRoles(email, ["admin"])` looks helpful until the day a test needs a manager role too: the helper grows arms and legs, every test ends up with
different default state, and the rules of what a valid record looks like live in a dozen places. A factory keeps that contract in one file and lets each test declare only
the field it actually cares about, leaving everything else to a valid default.

**Rules:**

- Every entity that appears in a test has a factory/builder in the shared factory surface, with named states for its meaningful variants.
- Tests prefer a named state over passing a bag of field overrides.
- Factories create required relationships themselves; tests wire relationships by hand only when the relationship is the subject of the test.
- Do not add per-file builder functions or wrapper helpers around factory calls — that is what a named state is for. Shared *logic* (not data) follows
  [Test Helper Classes](./test-helper-classes.md).
- A test asserts against values it set explicitly; never against a factory's incidental default.
- Default a child-record foreign key to a lookup that reuses an existing row in the current test context and only builds a parent when none exists. Do not memoize that
  reused id across tests: the database-reset harness rolls the row back and a cached id goes stale. Explicit overrides at the call site still win. Do not reuse both keys
  of a pair with a uniqueness or self-pair guard — derive the dependent key from the same parent, or pass both keys at the call site.
- Do not recompute an expensive one-way hash (password, API secret) on every factory create. Memoize one value per worker process. A hashed-column cast that detects an
  already-hashed string must not double-hash.
- Do not persist a nested parent while building the factory default map. Return a factory instance or a lazy lookup; persist nested parents only when the foreign key was
  not passed in.
- {{GEN:name this project's factory/builder mechanism for {{TEST_FRAMEWORK}} on {{STACK}}, where factories live given {{MODULE_LAYOUT}}, how an entity declares its
  factory, the idiom for a named state, and — if the stack has a tenant/owner scope on queries — the lookup shape that reuses a parent without a redundant owner clause.
  Detect and confirm.}}

**Example:**

{{GEN:two short {{TEST_FRAMEWORK}} snippets: (1) a bespoke record-assembling helper inside a test file ("Bad") versus a factory plus named state ("Good"); (2) a factory
default that persists a nested parent on every child ("Bad") versus a lazy lookup that reuses an existing parent ("Good").}}

> Severity for plan review: **BLOCK**.
