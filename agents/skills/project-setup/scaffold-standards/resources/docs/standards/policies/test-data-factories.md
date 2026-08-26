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
- {{GEN:name this project's factory/builder mechanism for {{TEST_FRAMEWORK}} on {{STACK}}, where factories live given {{MODULE_LAYOUT}}, how an entity declares its
  factory, and the idiom for a named state. Detect and confirm.}}

**Example:**

{{GEN:a short {{TEST_FRAMEWORK}} snippet contrasting a bespoke record-assembling helper inside a test file ("Bad") with a factory plus named state ("Good").}}

> Severity for plan review: **BLOCK**.
