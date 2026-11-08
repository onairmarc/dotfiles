# React and Inertia Policy Pack

**Pack gate:** `package.json` requires `react` and an Inertia client adapter (`@inertiajs/react` or equivalent).

Policies in this pack state client/server contract mechanisms that only apply to React applications rendered through Inertia. Adopt the pack only after confirming it
with the user; apply each policy only when its individual gate matches.

| Policy file                         | Severity | Index category | Individual gate                                                                  | Supersedes core policy |
|-------------------------------------|----------|----------------|----------------------------------------------------------------------------------|------------------------|
| `react-domain-state-composition.md` | BLOCK    | Frontend       | A TanStack Query dependency is installed                                         | —                      |
| `inertia-wire-contracts.md`         | BLOCK    | Frontend       | The project generates, ships, or otherwise owns typed server-to-client contracts | —                      |
| `react-inertia-data-driven-tests.md` | BLOCK    | Testing and documentation | A component or browser test runner supports `test.each` or `it.each` | —                      |

**Notes for the skill:**

- `react-domain-state-composition.md` extends `frontend-component-testing.md` when that conditional core policy is written. Its canonical-record rule does not change
  component-testing ownership.
- `inertia-wire-contracts.md` extends the project's DTO policy. When a Laravel pack replaces `data-transfer-objects.md` with `eloquent-vs-dto.md`, link there;
  otherwise link to the core policy.
- `react-inertia-data-driven-tests.md` extends `testing.md`; write both and have `testing.md` link to the pack policy when it is written.
- Add a `Frontend` section to `policies.md` when `react-domain-state-composition.md` or `inertia-wire-contracts.md` is written. Add
  `react-inertia-data-driven-tests.md` to the existing Testing and documentation section.
- The generated root `AGENTS.md` must route frontend state, wire-contract work, and data-driven component-test work to the written pack policies.
