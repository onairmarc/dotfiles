---
name: filament-service-conversion
description: Audits a Filament directory (resources, pages, actions, relation managers, custom fields) for business logic that belongs in service classes, maps each extraction to a target service with exact method signatures and frozen UI surfaces, then delegates to the feature-planning skill to produce a self-contained, phased, agent-ready extraction plan. Does NOT execute the extraction. A single failing test in the plan's Phase 0 baseline gate is a hard stop.
argument-hint: "<filament-path> [additional context]"
allowed-tools:
    - Read
    - Grep
    - Glob
    - Bash(test -f *)
    - Bash(test -d *)
    - Bash(find * -name "*.php" -type f)
    - Skill(feature-planning)
    - Skill(file-operations)
    - AskUserQuestion
---

# Filament → Service Class Conversion Skill

You are an expert Laravel architect. Your job is to **audit** a Filament directory, find every piece of business logic living inside Filament classes, map each piece to a
service-class extraction, and then invoke the **feature-planning skill** to produce a self-contained, agent-ready extraction plan. You do not execute any extraction code
yourself.

The end state the plan must describe: every Filament class becomes a **thin adapter** — it gathers raw form/action input, calls a service method with plain PHP arguments
(models + arrays/scalars), and maps the result to notifications, redirects, and UI state. Success means a future UI port (Inertia/React, Livewire Volt, an API) can call
the same service methods with the same argument shapes, making that port purely UI work.

Read the `file-operations` skill before performing any file operation.

**Input:** `$ARGUMENTS` — the Filament path to audit (e.g. `src/Filament`, `app/Filament`, `app_modules/Core/src/Filament`).

---

## Step 0 — Validate input

Parse `$ARGUMENTS`. Extract:

- `FILAMENT_PATH` — first positional argument (required). If missing or the path does not exist, abort with:
  ```
  Error: FILAMENT_PATH is required. Usage: /filament-service-conversion <path/to/Filament> [additional context]
  ```
- `EXTRA_CONTEXT` — everything after the first positional argument (optional). Free-form text the caller provides about known constraints, in-flight work, or extractions
  already decided (e.g. "the upload path already delegates", "Ticket 1234 changed the cache payload shape"). Preserve it verbatim and treat it as authoritative.

Derive:

- `MODULE_PATH` — the module root containing `FILAMENT_PATH` (usually its parent, e.g. `src/Core` for `src/Core/Filament`).
- `SERVICES_PATH` — the sibling services directory. Look for an existing `Services/` directory under `MODULE_PATH` (or `app/Services` for a plain app). If none exists,
  ask the developer via `AskUserQuestion` where extracted services should live before continuing.
- `MODULE_NAME` — the last meaningful segment of `MODULE_PATH` (if the last segment is `src`, use its parent).
- `TEST_ROOT` — the test directory covering `MODULE_PATH` (repo-root `tests/`, `application/tests/`, or a package-local `tests/`).

Emit before continuing:

```
Module:        {MODULE_NAME} ({MODULE_PATH})
Filament path: {FILAMENT_PATH}
Services path: {SERVICES_PATH}
Test root:     {TEST_ROOT}
```

---

## Step 1 — Discover project standards & policies (mandatory)

Locate where this project documents its coding standards, conventions, and policies. The extraction plan must not violate a single one, and the audit itself must not
propose an extraction the standards forbid.

1. Read the repo-root `README.md` and `AGENTS.md` (and any per-module `AGENTS.md` / `README.md` for `MODULE_PATH`) and follow every link they make to
   standards/policy/convention documents (e.g. `docs/standards/`, `docs/policies.md`, `CONTRIBUTING.md`, a `standards/` directory).
2. If neither file names a standards location, search with `Grep`/`Glob`: `docs/standards/`, `docs/policies*.md`, `docs/conventions*.md`, `CONTRIBUTING.md`, and any file
   whose name contains `standard`, `policy`, or `convention`.
3. When the location was not explicitly declared, confirm with the developer which document (s) you believe are the project's standards before relying on them; if you
   find none, say so explicitly.
4. Read them in full and record the concrete rules as `PROJECT_STANDARDS`. Pay special attention to policies governing typing, DTOs, logging, immutable dates,
   `final`/`readonly` usage, magic values, test conventions, and documentation — extractions routinely touch all of them. Pass this to feature-planning in Step 6.

### Standards reconciliation — the DTO question

Extraction plans frequently collide with two standards pulling opposite ways: a strong-typing policy that forbids loosely-keyed arrays as data-transfer shapes, and an
internal-calls policy that forbids introducing DTOs for intra-module calls. When both exist, the service ↔ Filament boundary is an intra-module call, so **default to
plain arrays and scalars** and record the strong-typing deferral explicitly in the plan.

There is also a correctness reason to prefer arrays here: Filament hands actions a **sparse** payload — only the keys for form sections the admin actually touched — and
`$model->fill()` writes only the keys present. A DTO with nullable-defaulted properties would write every column, silently nulling fields whose form section was never
expanded. Do not introduce DTOs on the extracted surface unless the project already uses an optional/undefined-property construct (e.g. `Spatie\LaravelData\Optional`) and
the standards mandate it. Typed DTOs belong with the eventual UI port, where an HTTP boundary and `FormRequest` validation make them correct.

Resolve any other standards conflict the same way: name both policies, pick the behavior-neutral side, and record the decision and its rationale in the plan.

---

## Step 2 — Inventory the Filament surface

Enumerate every class under `FILAMENT_PATH`: resources, resource pages (Create/Edit/List/View), custom pages, actions, bulk actions, relation managers, form
schemas/components, table columns, custom fields, widgets, and helpers. For each class, **read the file** — never classify from the name alone — and sort it into exactly
one bucket:

### Bucket A — Extract (contains business logic)

Any of the following found inside a Filament class is business logic and must move to a service:

| Logic type                     | Typical Filament host                                                                                      |
|--------------------------------|------------------------------------------------------------------------------------------------------------|
| Model persistence              | `->action()` closures, `handleRecordCreation`, `mutateFormDataBeforeSave/Create`, `save()` overrides       |
| Data transformation            | `mutateFormDataBefore*` hooks, slug derivation, option-array builders, default-value injection             |
| Event / job dispatch           | Action closures dispatching jobs or events alongside persistence                                           |
| Publishing / state transitions | Publish/unpublish/activate actions that flip flags, stamp timestamps, or cascade to related models         |
| External-service orchestration | Pages calling HTTP clients, DNS/domain APIs, media libraries, cache reads with TTLs                        |
| Delete guarding                | `->before()` predicates and bulk-delete loops that decide *whether* a record may be deleted                |
| Query logic                    | Inline `Model::query()` selects feeding form options, table state, or pagination beyond Filament built-ins |

### Bucket B — Out of scope (record explicitly, do not extract)

| Category                           | Rule                                                                                                                                    |
|------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| Trivial default-CRUD pages         | Pages whose only code is `$resource`, `getTitle()`, and header-action composition are already pure. Leave untouched.                    |
| Filament-framework-owned mutations | Attach/detach/reorder via `AttachAction`, `DetachAction`, `->reorderable()`, `CheckboxList->relationship()`, `FileUpload->disk()`.      |
| Presentation / view-model helpers  | Status-color pickers, human-readable descriptions, `match` label mappings, `<img>`/data-URI wrapping. They die with the UI port.        |
| RBAC gates                         | `->authorize()`, `canAccess()`, policy checks. Authorization stays at the UI/policy layer, unchanged.                                   |
| Livewire-coupled reflection        | Code that introspects the live Livewire component (property-type detection, state hydration/dehydration). Meaningless outside Filament. |
| Fill-side hydration hooks          | `mutateFormDataBeforeFill` that only reads model state into form state. Only save-side logic is extracted.                              |
| Base-class-owned persistence       | Save paths inherited from a vendor/shared base (e.g. a settings-page `save()`); the subclass has nothing of its own to extract.         |

Every Bucket B class the developer might *expect* to be converted must appear in the plan's Out of scope section with a one-line reason — silence reads as an oversight.

### Live-binding boundary rule

When a closure mixes a live Filament binding with a derivation (e.g. an `afterStateUpdated` that auto-slugs only while the record is unpublished), the **guard stays in
the Filament closure** and only the **derivation** moves to the service. Similarly, calls to `request()` never move into a service — the Filament layer reads the request
and passes the value as a plain argument.

---

## Step 3 — Trace frozen surfaces (mandatory, before mapping anything)

Behavior neutrality is the plan's success criterion, and tests define what "behavior" means. Before mapping a single extraction, sweep `TEST_ROOT` for every test that
touches `FILAMENT_PATH` or the services it will extend, **read each one**, and record every coupling that freezes a surface:

- **Reflection grabs** — `new ReflectionMethod(SomeAction::class, "someMethod")`. The method's name, staticness, visibility, and parameter types are frozen.
- **Container swaps via anonymous subclass** — `new class extends SomeService` registered with `app()->instance(...)`. The overridden method must stay an ordinary public
  method (not `final`, not `abstract`), and the calling code must keep resolving the service from the container.
- **Direct calls to page/action methods** — a test calling a `protected`/`public` method on a Filament class directly. The class keeps a forwarding method of the same
  name and signature that delegates to the service.
- **Livewire assertions** — `livewire(...)->callAction("Name")`, `assertFormSet`, `assertNotified`, `assertDispatched`. Action names, form field names, notification
  titles, and dispatched event names/payloads are all frozen.
- **Job/event constructor signatures** — tests that construct or fake dispatched jobs freeze their constructors and `dispatch()`/`handle()` shapes.

Also record **coverage gaps**: where a feature test is render/permission smoke only and asserts nothing about the behavior being moved, note it — the plan's new service
tests are the only regression signal for that extraction, and the plan must say so.

Finally, inventory **how the surrounding code resolves services** (a `HasMake`-style `::make()`, a hand-rolled static `make()`, container `app(...)`, constructor
injection) per service. The plan must resolve each service the way its existing call sites already do — matching surrounding code beats uniformity. If the module has a
class that is already the target shape (thin action closures calling services), name it as the reference pattern to copy.

---

## Step 4 — Map extractions

For each Bucket A finding, produce a mapping entry:

- **Source** — `Class::method()` (or closure host), exact file path relative to repo root, exact line range. Read the file to confirm lines; never approximate.
- **Target service** — an existing service to extend when one owns the domain, or a new service (with its full path under `SERVICES_PATH`) when none does. Prefer
  extending; create new services only for domains with no existing home. Follow the module's existing subdirectory layout when placing new services.
- **Proposed method signature (s)** — full PHP signatures with parameter and return types, plus `array{...}`/`@return` docblocks for array shapes and collections. Where
  the moved body is short, include it verbatim so the plan is copy-ready.
- **What stays in the Filament class** — notifications, exception→notification mapping, redirects, `$this->dispatch(...)`, form re-fills, RBAC gates, guards on live
  bindings, and any frozen forwarding method from Step 3.
- **Seams preserved** — the specific frozen surfaces from Step 3 this extraction touches, stated as constraints.
- **Opportunistic policy fixes** — when a moved call site violates a BLOCK-severity standard (deprecated logger, mutable `now()`, magic string with an existing enum), the
  move converts it; note the exact replacement. Do not fix violations in code the plan does not touch.

Group the entries by **domain** (one service or tightly-coupled service cluster per domain). Domains must be independently landable in any order; within a domain the
service (and its tests) always lands before the Filament class that calls it.

The guiding contract every mapping must satisfy:

1. Service methods take models + plain arrays/scalars and return models/values/void or throw typed exceptions. They never reference `Filament\*`, `Notification`,
   `Livewire`, `Get`/`Set`, or a page/record context object.
2. The Filament class keeps its public Livewire surface identical — same action names, form field names, computed-property names, dispatched events, notifications.
3. Container seams that tests fake stay container-resolved, with method shapes that keep the fakes compiling.
4. Services are resolved the way the surrounding code already resolves them.

---

## Step 5 — Compile findings

Prepare this structured summary:

```
## Extraction audit: {MODULE_NAME}

Filament path:  {FILAMENT_PATH}
Services path:  {SERVICES_PATH}
Test root:      {TEST_ROOT}
Caller context: {EXTRA_CONTEXT | "(none)"}

Domains: N   Extractions: N   Out-of-scope classes recorded: N   Frozen surfaces: N   Coverage gaps: N

### Reference pattern
{class already in the target shape, or "(none found)"}

### Frozen surfaces
- {test file:line} — {what it freezes and how}
[...]

### Domain: {name}
Target: {Services/Foo.php (extend) | Services/Bar/Baz.php (new)}
- `Source::method()` at `path/file.php:10-25` → `targetMethod(signature)` — {one-sentence description}; stays behind: {notifications/guards/...}
[...]

### Out of scope
- `path/Class.php` — {reason bucket + one line}
[...]

### Coverage gaps
- {feature test} covers render only; service tests are the sole regression signal for {domain}
[...]
```

If any mapping requires a genuine developer decision (competing standards with no behavior-neutral winner, a seam that cannot be preserved without changing a test's
intention, an ambiguous domain owner for a shared helper), resolve it via `AskUserQuestion` **before** the handoff — never leave an open question inside the plan.

---

## Step 6 — Invoke feature-planning

Hand off to the **feature-planning skill** with the full audit summary as context. Use the following as the feature description passed to feature-planning (feed it
programmatically — do not ask the user to retype it):

---

> Filament → service-class extraction plan for `{MODULE_NAME}` (`{FILAMENT_PATH}` → `{SERVICES_PATH}`).
>
> This is NOT a new feature — it is a behavior-neutral refactor that relocates business logic out of Filament classes into service classes. The plan must follow the
> standard feature-planning plan structure with these overrides:
>
> **Success criteria (state verbatim in the plan's Goal):** No observable behavior change. The admin UI, the module's public API, and every action name, form field,
> notification, dispatched event, and container seam behave exactly as they do today. Existing tests are not modified except for mechanical updates the plan
> enumerates explicitly, file by file and line by line; no test's *intention* changes.
>
> **Replace "Implementation steps" with phases:**
>
> **Phase 0 — Baseline (mandatory, non-negotiable)**
> - Run the full test suite and static analysis using the repo's own commands (discover them from the standards docs / CI config; do not guess).
> - Record a green baseline. If anything fails at baseline, stop and report — do not begin extraction on a red suite.
>
> **Phase 1..N — one phase per domain, in the dependency order the audit identified (or any order when domains are independent — say which).** Within each phase:
> - Extend or create the service first, with its exact method signatures and (where provided) verbatim bodies from the audit.
> - Add or extend the service's unit tests next, following the repo's existing test layout and conventions (append to the per-service test file where one exists).
> - Only then edit each Filament class to delegate, keeping every frozen surface from the audit intact.
> - Close the phase by running the named feature/unit test files for the domain, then the full suite. A single failing test = that step is a failure. Revert and fix
>   before continuing.
>
> **Final phase — gate + documentation.** Full suite + static analysis green; land the module/architecture documentation updates the project's documentation policy
> requires (note the new services, the thin-adapter contract, the reference pattern, and every preserved seam); follow the repo's plan-lifecycle rules for the plan
> file itself.
>
> **Hard constraints to embed in the plan:**
> 1. Every extraction cites exact file path and line range — no approximations.
> 2. Service methods take models + plain arrays/scalars and return models/values/void or throw typed exceptions. They never reference `Filament\*`, `Notification`,
>    `Livewire`, `Get`/`Set`, or a page/record context object. Never call `request()` inside a service — the Filament layer passes request-derived values as plain
>    arguments.
> 3. Every Filament class keeps its public Livewire surface identical: action names, form field names, computed-property names, dispatched events, notifications,
>    and exception→notification mappings all stay in the Filament layer.
> 4. Every frozen surface from the audit (reflection grabs, container-swap fakes, direct method calls, job/event constructors) is listed as a named constraint on
>    the step that touches it. Container seams stay container-resolved; faked methods stay ordinary public methods.
> 5. Services are resolved the way their existing call sites already resolve them (`::make()`, `app(...)`, injection). Matching surrounding code beats uniformity.
> 6. Guards bound to live Filament state stay in the Filament closure; only derivations move.
> 7. No DTOs on the extracted service surface (see the audit's standards reconciliation); plain arrays preserve Filament's sparse-payload `fill()` semantics. Record
>    the strong-typing deferral in the plan and the merge request.
> 8. Within a domain, the service and its tests land before any Filament class that calls them. Run the full suite after each domain.
> 9. Phase 0 is non-negotiable. A single test failure after any step = hard stop. Revert, fix, re-run.
> 10. No new configuration keys, no migrations, no dependency changes. Cache keys, TTL literals, and column values move verbatim.
> 11. Opportunistic BLOCK-policy fixes apply only to call sites the plan already moves or opens, exactly as the audit enumerated them.
> 12. Where the audit flagged a coverage gap, the plan states that the new service tests are the sole regression signal for that domain.
> 13. Every step must comply with the project's documented standards and policies (below). Where an extraction would conflict with a policy, honor the policy and
>     note the constraint on the step; if the two genuinely cannot be reconciled, flag it for developer review rather than shipping the violation.
>
> **Out of scope (carry the audit's list verbatim, with reasons):**
>
> {BUCKET_B_LIST}
>
> **Project standards & policies to comply with** (discovered in Step 1 — the plan must not violate a single rule; give these extra attention):
>
> {PROJECT_STANDARDS | "(none found — state this explicitly in the plan)"}
>
> **Caller-supplied context** (treat as authoritative — may describe constraints not discoverable by static analysis):
>
> {EXTRA_CONTEXT | "(none provided)"}
>
> **Audit findings to address:**
>
> {FULL_AUDIT_SUMMARY_FROM_STEP_5}

---

The feature-planning skill handles the rest: discovers the planning directory, drafts the plan, applies review lenses, iterates with the user, and writes the final
agent-ready plan to disk.