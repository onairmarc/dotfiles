# React and Inertia Policy Pack

**Pack gate:** `package.json` requires `react` and an Inertia client adapter (`@inertiajs/react` or equivalent).

Policies in this pack state client/server contract mechanisms that only apply to React applications rendered through Inertia. Adopt the pack only after confirming it
with the user; apply each policy only when its individual gate matches.

| Policy file                         | Severity | Index category | Individual gate                                                                  | Supersedes core policy |
|-------------------------------------|----------|----------------|----------------------------------------------------------------------------------|------------------------|
| `react-domain-state-composition.md` | BLOCK    | Frontend       | A TanStack Query dependency is installed                                         | —                      |
| `inertia-wire-contracts.md`         | BLOCK    | Frontend       | The project generates, ships, or otherwise owns typed server-to-client contracts | —                      |

**Notes for the skill:**

- `react-domain-state-composition.md` extends `frontend-component-testing.md` when that conditional core policy is written. Its canonical-record rule does not change
  component-testing ownership.
- `inertia-wire-contracts.md` extends the project's DTO policy. When a Laravel pack replaces `data-transfer-objects.md` with `eloquent-vs-dto.md`, link there;
  otherwise link to the core policy.
- Add a `Frontend` section to `policies.md` when either policy is written.
- The generated root `AGENTS.md` must route frontend state and wire-contract work to the written pack policies.
