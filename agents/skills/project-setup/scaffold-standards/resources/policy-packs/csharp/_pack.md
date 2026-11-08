# C# Policy Pack

**Pack gate:** The repository contains a `.sln` file or one or more `*.csproj` files.

Policies in this pack state .NET-specific mechanisms that the language-agnostic core templates leave open. Adopt the pack only after confirming it with the user;
apply each policy only when its individual gate matches.

| Policy file         | Severity | Index category               | Individual gate                                                   | Supersedes core policy |
|---------------------|----------|------------------------------|-------------------------------------------------------------------|------------------------|
| `xunit-theories.md` | BLOCK    | Testing and documentation    | A test project references xUnit (`xunit`, `xunit.v3`, or runner) | —                      |

**Notes for the skill:**

- `xunit-theories.md` extends `testing.md`; write both and have `testing.md` link to the pack policy when it is written.
- The policy applies to xUnit attributes only. NUnit and MSTest projects keep the language-agnostic rule until they receive their own pack policy.
- Add `xunit-theories.md` to the existing Testing and documentation section in `policies.md`.
- The generated root `AGENTS.md` must route xUnit test changes to `xunit-theories.md` when the file is written.
