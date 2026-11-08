# xUnit theories

Use `[Theory]` with one visible data row per scenario when one xUnit test body proves the same contract for different declared inputs and expected outputs.

Duplicate `[Fact]` bodies hide their shared contract and make the next case harder to add. A theory keeps the invocation and assertion in one place while leaving
every scenario visible as `[InlineData]` or `MemberData`.

**Rules:**

- Prefer `[Theory]` when every case shares one setup, invocation, cleanup path, and assertion shape. A one-row theory is valid when the contract is naturally
  data-driven and another row can be added without changing the method body.
- Use `[InlineData]` for attribute-supported values. Use the project's existing `MemberData` pattern for complex values or generated rows.
- Preserve every converted fact as one independently visible theory data row. Do not remove a source case unless its input and asserted contract remain in that row.
- Keep `[Fact]` or an existing specialized test attribute when a case differs in fixture state, asynchronous sequencing, cancellation, collection, timeout, platform
  requirement, resource lifetime, or asserted behavior.
- Keep existing shared builders and fixtures. Do not add a helper only to package theory data.
- {{GEN:name the xUnit version, test-project locations, test command, and existing `MemberData` pattern. Detect them from project files and tests, then confirm them
  with the user.}}

**Example:**

```csharp
[Theory]
[InlineData("", false)]
[InlineData("invalid", false)]
[InlineData("station@example.com", true)]
public void IsValidEmail_Input_ReturnsExpected(string value, bool expected)
{
    bool actual = validator.IsValidEmail(value);

    actual.Should().Be(expected);
}
```

> Severity for plan review: **BLOCK**.
