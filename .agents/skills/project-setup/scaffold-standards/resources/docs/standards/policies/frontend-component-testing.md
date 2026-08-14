# Frontend Component Testing

User-interface components ship colocated component tests that assert observable output — what a user can see and do — not internal component state.

A component test that reaches into internal state passes while the rendered output is broken, and fails on every refactor that does not change behavior. Asserting what
the user observes — the text on screen, the enabled control, the request that fires on submit — is the only assertion that tracks the actual contract. Colocating the test
with the component keeps the pair visible: a component without a neighboring test is obvious at a glance.

**Rules:**

- Every component with behavior — conditional rendering, user input, data fetching — ships a test next to it.
- Assertions target observable output: rendered text, accessible roles, emitted events, issued requests. Never internal state or private methods.
- Query the way a user would (by role, label, or visible text) rather than by implementation-detail selectors.
- Asynchronous behavior is awaited through the test library's utilities, never with a fixed sleep.
- Mock at the network boundary; do not mock the component's own children to make an assertion easier.
- {{GEN:name this project's component test runner and testing library, the exact run commands (full suite and single file), the colocation convention and file-naming
  pattern, and which parts of the frontend the policy covers. Detect and confirm.}}

**Example:**

{{GEN:a short component-test snippet in this project's runner contrasting an assertion against internal state ("Bad") with an assertion against rendered, user-observable
output ("Good").}}

> Severity for plan review: **BLOCK**.
