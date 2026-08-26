# Type Sealing

Sealing keywords — the ones that forbid subclassing, overriding, or reassignment — are applied deliberately, not by default and not by a generator.

Sealing constrains how a type may evolve. In a codebase where a module frequently extends a base type to slot into an existing surface, sealing by default locks doors
nobody meant to lock, and the cost lands on whoever needs the extension six months later. The reverse position — seal everything — is equally defensible in a codebase
that is not extended that way. What is *not* defensible is a codebase where the answer varies by whichever generator emitted the file, so this policy fixes the default.

**Rules:**

- {{GEN:state this project's default — sealed-by-default or open-by-default — naming the exact keywords in {{PRIMARY_LANGUAGE}} the rule covers. Ask the user; this is a
  project decision, not a detectable default.}}
- Deviating from the default is a deliberate choice made in the pull request that introduces the type, with the reason stated.
- Do not flip a type's sealing during an unrelated refactor.
- When a code generator emits the non-default form, correct it before committing.

> Severity for plan review: **WARN**.
