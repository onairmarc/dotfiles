# Test Helper Classes

Shared test logic lives as named, importable members of a dedicated helper type under the test-support tree — never as a free-floating helper declared inside a test file.

A helper declared in a test file is effectively a global: two files that pick the same name can collide, the helper's owner is untraceable from a call site, and tooling
cannot see who uses it. A named helper type gives every helper exactly one home, an importable name, and a place for the comment explaining what it builds and why. This
governs test *logic* — scenario composition, harness construction, measurement of results. Test *data* stays governed by [Test Data Factories](./test-data-factories.md):
a helper must not wrap or re-default a single entity's factory, though it may compose a multi-entity scenario whose relationships are the subject under test.

**Rules:**

- No helper declarations inside a test file — not at file level and not nested inside a grouping block.
- Shared helpers are members of a helper type under the test-support tree, discoverable by the project's normal import mechanism.
- Call sites use the qualified name so the helper's owner is visible at the call site.
- One helper type per cohesive concern, not one grab-bag type per module.
- Existing file-level helpers are grandfathered until the file is next edited; an edit converts its helpers to a helper type in the same change.
- {{GEN:the test-support directory and import/autoload mechanism for {{PRIMARY_LANGUAGE}} given {{MODULE_LAYOUT}}, and the naming convention for a helper type. Detect and
  confirm.}}

**Example:**

{{GEN:a short {{TEST_FRAMEWORK}} snippet contrasting a file-level helper declared in a test file ("Bad") with the same helper as a member of a named helper type, called
by its qualified name ("Good").}}

> Severity for plan review: **BLOCK**.
