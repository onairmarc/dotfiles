# Inertia wire contracts

Server-owned API and Inertia shapes have one typed definition. The client consumes generated or package-shipped contract types, while local TypeScript types describe only
browser state, callbacks, route parameters, or presentation-only composition.

Duplicating a server contract in TypeScript turns a server field change into a silent client drift. Keeping independently produced Inertia props separate also preserves
the ownership boundary between middleware, controllers, and client state.

**Rules:**

- Use the generated or package-shipped type for every API request, API response, or Inertia prop that mirrors a server-owned contract. Never hand-write a duplicate
  client record.
- Keep a TypeScript type local only when it contains browser objects, callbacks, route parameters, UI defaults, or a presentation-only composition of server responses.
- Do not generate framework-owned envelopes. Compose generated domain records with types shipped by the framework or component package that owns the envelope.
- Keep separately produced Inertia props separate. Middleware and controllers each own their props; Inertia combines them in the final response.
- When one response combines several server facts, define narrow server-owned fragments and compose them at the controller or renderer that owns the response. TypeScript
  may compose those generated fragments but must not redeclare their fields.
- Inertia bootstraps the page. TanStack Query owns later mutable and refreshable API state.
- {{GEN:name the contract generator or package-owned declaration path, its command, whether generated output is committed, and the app-owned source directories it scans.
Detect the pipeline and confirm with the user.}}

**Example:**

```ts
// Bad - duplicates a server-owned response contract.
type Event = { id: number; title: string };

// Good - named local UI state composes with generated server data.
type EventFormUiState = {
    startsAt: Dayjs;
    isDialogOpen: boolean;
};

type EventFormValues = EventData & EventFormUiState;
```

> Severity for plan review: **BLOCK**.
