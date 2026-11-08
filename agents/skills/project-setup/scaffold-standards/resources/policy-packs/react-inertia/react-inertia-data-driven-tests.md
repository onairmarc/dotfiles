# React and Inertia data-driven tests

Use the configured runner's `test.each` form when one React or Inertia test body proves the same observable contract for different declared inputs and
expected outputs.

Copy-pasted component tests drift: a later fix updates one assertion or interaction but misses another. A visible case table keeps equivalent states together.
It lets a new state extend the same contract without duplicating render, interaction, and assertion code.

**Rules:**

- Use `test.each` when every case uses the same render setup, user interaction, async wait, and assertion shape.
- Make each former case visible in the data table, and include its label in the test name so a failed row identifies the scenario.
- Keep separate tests when a case needs a different provider, route, server response, mock lifecycle, user workflow, accessibility assertion, or cleanup path.
- Assert rendered, user-observable behavior through the project's testing library. A data table must not turn a user workflow into an assertion against component
  state.
- {{GEN:name the configured test runner's parameterized-test API, the testing-library render helper, and the command that runs one test file. Detect these from the
  package manifest and existing tests, then confirm them with the user.}}

**Example:**

```ts
test.each([
    ['empty name', '', 'Name is required'],
    ['short name', 'A', 'Name must be at least 2 characters'],
])('shows an error for %s', async (_caseName, name, expectedMessage) => {
    const user = userEvent.setup();
    render(<StationForm / >);

    await user.type(screen.getByLabelText('Name'), name);
    await user.click(screen.getByRole('button', {name: 'Save'}));

    expect(await screen.findByText(expectedMessage)).toBeVisible();
});
```

> Severity for plan review: **BLOCK**.
