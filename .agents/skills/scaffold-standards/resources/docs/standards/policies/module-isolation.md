# Module Isolation

**All** cross-module access — reads as well as writes — goes through a service method on the owning module. A module never queries another module's data directly.

When one module reaches into another's data, the dependency graph silently becomes a tangle and neither module can be reasoned about — or extracted — in isolation. A
service method is the promise: the owning module may rename a column, add a scope, split a table, or move behind a cache without breaking anyone, because no consumer ever
named its internals. The moment a read is written inline in another module, that freedom is gone — the owning module cannot see who depends on the shape, so every
refactor becomes an archaeology exercise across the whole repository.

Reads and writes are the same case. Both hard-code another module's tables, column names, relationships, and rules into a file its owner does not maintain, so both are
service methods. There is no read exemption to look for and no threshold of repetition to reach first: one caller is enough, because the method exists to own the
boundary, not to deduplicate the call.

Shared primitives get a legitimate home so that "everyone needs this" never becomes an excuse to reach across a boundary.

This file carries the **full boundary contract**: the policy rules below, then the reach model — where the boundaries run, what counts as published, how a service method
is written, and the per-module working list.

**Rules:**

- **Every cross-module touchpoint is a service method on the owning module.** Reads included. A module calls `OtherModule\SomeService::method()`; it never writes a query
  against another module's models, tables, or repositories.
- **Each module owns its data and its invariants. Mutations to a module's state go through its service surface** so validation, events, and side effects fire. Never write
  another module's persistent state directly.
- **The service method exists from the first call site**, for reads and writes alike. There is no "inline it now, extract it when it repeats" path and no repetition
  threshold. One caller is enough — a deliberate exception to [Simplicity First](./simplicity-first.md), because what the method protects is the boundary, not the call
  count.
- A module never imports, queries, or constructs another module's models, query builders, repositories, or persistence types. Those are internal to the owning module, as
  are its jobs, handlers, HTTP and UI layers, and private helpers.
- What a service method **returns** may be the owning module's own domain object — the consumer reads it, it does not query it. Receiving an object across the boundary is
  fine; reaching across the boundary to fetch one is not.
- Cross-module signaling uses events; the handler lives in the consuming module.
- Internal background work stays internal — another module asks the owner to run it rather than dispatching it directly.
- A grouping directory is not a back door: nested modules follow the same rules as top-level ones.
- Adding or removing a long-lived cross-module touchpoint follows [When the boundary moves](#when-the-boundary-moves).
- {{GEN:name this project's modules given {{MODULE_LAYOUT}}, where a module's service classes live and how another module resolves one in {{PRIMARY_LANGUAGE}}
  (interface/contract directory, facade, container binding, public package export), and which module holds shared primitives. Detect and confirm.}}

**Example:**

{{GEN:a short {{PRIMARY_LANGUAGE}} snippet showing one cross-module **read** and one cross-module **write**. "Bad": both done directly against the other module's model —
an inline query, and a direct state change. "Good": both done by calling service methods on the owning module. Show those service methods defined on the owning side so
the reader sees where the query and the mutation now live. Present the two cases identically; the rule does not distinguish between them.}}

> Severity for plan review: **BLOCK**.

---

## The reach model

How **{{PROJECT_NAME}}** treats reach across `{{MODULE_LAYOUT}}` — where the boundaries are, what counts as published, and what a coding agent should be confident about.

### Principles

1. **Module boundaries are architectural, not organizational.** The layout is not merely a filing convention for related files; it is a contract layer. Every touchpoint
   between two modules is wrapped in a service method, and that is the point rather than an overhead to be minimized.
2. **Each module owns its data model.** The owning module is responsible for its invariants, validation, side effects, and any external-sync paths for the data it owns.
   Nothing outside the module queries that data.
3. **The service method is the unit of coupling.** A cross-module dependency should be countable: every one is a named method on a named service, so the owning module can
   list its consumers and change everything behind them. An inline query is an uncountable dependency — invisible to the owner until it breaks.
4. **Reads and writes are the same case.** Both couple the caller to another module's schema, so both are service methods on the owning module, from the first caller
   onward. The policy draws no distinction between them and no exception for either.
5. **Mutations with invariants go through the owning module.** When a change has validation, events, or domain rules attached, route through the owning module so those
   fire. Never write another module's persistent state directly.
6. **Internal jobs/tasks stay internal.** If a module defines an internal background task, that module decides when and how it runs. Other modules ask it (a call, an
   event) and let it dispatch.
7. **Platform primitives are universal.** Cross-cutting primitives may be referenced from any module without ceremony. This is the one exception, and it covers framework
   and shared-kernel types — not another module's domain data.

### What "public" means

A module's published surface is the set of things other modules may rely on for the long term.

{{GEN:a bulleted list of what counts as this project's published surface, mapped to its actual layout ({{MODULE_LAYOUT}}) and {{PRIMARY_LANGUAGE}} conventions — public
service classes/interfaces, emitted events, and exported value objects/DTOs. **Models, query builders, repositories, and persistence types are explicitly NOT published**,
even when the language makes them importable; say so in a line of its own. Then a one-line statement of which directories/namespaces are internal (models, jobs, handlers,
HTTP, UI, helpers) and free to refactor without coordination.}}

### Writing the service method

The first time a module needs to read or change data owned by another module, that operation is added as a method on the owning module's service and called from there.

Put the method where the data lives, not where it is needed. Name it for what the caller wants (`activeSeatsFor(Account $account)`, `suspendSeat(Seat $seat)`), not for
the query or update it happens to run today — that is what lets the owner change the implementation later. Keep the filtering inside the method rather than returning a
builder the caller narrows further, because a returned builder re-exposes the schema the method was written to hide.

This deliberately overrides [Simplicity First](./simplicity-first.md)'s "do not add an abstraction for a single caller." That rule is about speculative abstraction
*inside* a module; here the abstraction is not speculative — it is the boundary itself, and its value does not scale with the number of callers.

### What is allowed

{{GEN:a table with columns "touchpoint", "allowed?", "notes" enumerating the concrete cross-module operations for this project's stack. Author the Yes/No calls consistent
with the Principles above and {{PRIMARY_LANGUAGE}} idioms. At minimum, mark as **No**: querying another module's models, importing its persistence types, joining to its
tables, writing its state directly, dispatching its internal jobs, and re-implementing its invariants. Mark as **Yes**: calling its public service methods, subscribing to
its events, and receiving its domain objects as return values.}}

### Exported contracts (boundary types)

Use an explicit boundary type at exported contracts — data crossing an HTTP/API request or response, an external integration, or a queue/serialization boundary where the
consumer cannot trust in-process state. Do not introduce a boundary type for an in-process call, **including one that crosses a module boundary**; passing the domain
object is fine there. The shape rules for those types are in [Data Transfer Objects](./data-transfer-objects.md).

{{GEN:name the concrete boundary-type mechanism this project uses (the DTO library, resource class, or serialization type for {{PRIMARY_LANGUAGE}}/{{STACK}}) and the
exact situations that require it. Omit if the project has no distinct boundary-type convention.}}

### Published surface per module — working list

This table is the working contract. Update it in the same change that alters a module's surface.

{{GEN:a table with a row per module discovered in {{MODULE_LAYOUT}}, columns "module", "public services/contracts", "public events", "public DTOs/value objects". Fill
from what is detectable and mark leaf consumers as such. Ask the user to confirm the module list. If the project is a single module, replace this whole section with a
one-line note that boundaries do not yet apply.}}

### When the boundary moves

Adding a long-lived cross-module touchpoint (a contract another module will rely on, or a public signature change with cross-team consumers):

1. Coordinate with the owning module's maintainer — that coordination is the point of the table.
2. Add the touchpoint to the working list above.
3. Update the owning module's `AGENTS.md` if the touchpoint introduces a commitment future refactors must respect.
4. Cover the touchpoint with a test.

Removing a cross-module touchpoint: remove every external consumer first, then update the table, then remove the touchpoint in a follow-up change.
