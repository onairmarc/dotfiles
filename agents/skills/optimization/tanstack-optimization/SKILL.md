---
name: tanstack-optimization
description: Audits a TanStack React path for library-specific performance issues (QueryClient recreated per render, missing staleTime, fetch-in-useEffect, N useQuery in a loop, unstable table columns/data, unbounded rows without virtualization, router created in render, whole-form store subscriptions), then runs react-optimization --audit-only on the same path and delegates to the feature-planning skill to produce a self-contained, phased, agent-ready optimization plan. Does NOT execute optimizations. A single failing test in the plan's Phase 0 baseline gate is a hard stop.
argument-hint: "<project-path> [additional context]"
allowed-tools:
    - Read
    - Grep
    - Glob
    - Bash(test -f *)
    - Bash(test -d *)
    - Bash(find * -name "*.tsx" -type f)
    - Bash(find * -name "*.jsx" -type f)
    - Bash(find * -name "*.ts" -type f)
    - Bash(find * -name "*.js" -type f)
    - Bash(cat *)
    - Skill(feature-planning)
    - Skill(react-optimization)
    - question
---

# TanStack Optimization Skill

You are an expert TanStack + React performance engineer. Your job is to **audit** a project path for TanStack-library issues, run the **react-optimization** skill as a
sub-audit, and then invoke the **feature-planning skill** to produce a self-contained, agent-ready optimization plan. You do not execute any optimization code yourself.

This skill owns TanStack-specific findings. General React findings come from `react-optimization --audit-only`, which itself loads `vercel-react-best-practices` or
`inertia-best-practices`. Do not re-audit React rules here.

**Input:** `$ARGUMENTS` — the project path to audit (e.g. `resources/js`, `src`, `apps/web`).

---

## Step 0 — Validate input

Parse `$ARGUMENTS`. Extract:

- `PROJECT_PATH` — first positional argument (required). If missing or the path does not exist, abort with:
  ```
  Error: PROJECT_PATH is required. Usage: /tanstack-optimization <path/to/project> [additional context]
  ```
- `EXTRA_CONTEXT` — everything after the first positional argument (optional). Free-form text the caller provides about known issues, architectural decisions, or
  constraints the automated audit may not discover (e.g. "the tickets table renders 10k rows", "Query default staleTime is set in main.tsx"). Preserve it verbatim.
- `AUDIT_ONLY` — set to `true` if `EXTRA_CONTEXT` contains the flag `--audit-only`. When set, **stop after Step 3.5**
  and emit the merged findings summary. Do **not** invoke feature-planning. Plan-review uses this so it can fold findings into an existing plan.

Derive `PROJECT_NAME` from the last meaningful path segment (if last segment is `src` or `js`, use its parent).

---

## Step 1 — Detect project type and installed TanStack libraries

Read `package.json` at `PROJECT_PATH`, then walk up to the repo root until you find one. Record every TanStack library actually installed (dependencies or
devDependencies). Only audit libraries that are present.

| Package                                                                              | Library key |
|--------------------------------------------------------------------------------------|-------------|
| `@tanstack/react-query`, `@tanstack/query-core`, `@tanstack/react-query-devtools`    | **Query**   |
| `@tanstack/react-table`, `@tanstack/table-core`                                      | **Table**   |
| `@tanstack/react-router`, `@tanstack/router-core`, `@tanstack/react-router-devtools` | **Router**  |
| `@tanstack/react-form`, `@tanstack/form-core`                                        | **Form**    |
| `@tanstack/react-virtual`, `@tanstack/virtual-core`                                  | **Virtual** |

If **zero** TanStack libraries are present, abort:

```
Error: no TanStack React libraries found in package.json. Usage is /tanstack-optimization on a path that depends on
@tanstack/react-query, react-table, react-router, react-form, or react-virtual.
```

Also classify the host React app (same signals as react-optimization):

| Signal                                                    | Classification          |
|-----------------------------------------------------------|-------------------------|
| `@inertiajs/react` (or `@inertiajs/vue3`) in dependencies | **Inertia Application** |
| `next` in dependencies                                    | **Next.js Application** |
| `vite` + `react`                                          | **Vite React App**      |
| otherwise, `react` present                                | **React Application**   |

Record as `PROJECT_TYPE` and `TANSTACK_LIBS` (the library keys above).

Scope: `PROJECT_PATH` only, plus (Inertia) the named Laravel controllers that feed pages under it. Out of scope:
`node_modules/`, `vendor/`, `.next/`, `dist/`.

Determine test root and runner from `package.json` scripts and devDependencies (prefer `vitest`, then `jest`).

Emit before continuing:

```
Project type: {PROJECT_TYPE}
Project:      {PROJECT_NAME} ({PROJECT_PATH})
TanStack:     {TANSTACK_LIBS}
Test root:    {TEST_ROOT}
Test runner:  {TEST_RUNNER}
```

This skill owns the feature-planning handoff (including the merged React findings), so it must discover standards even though it calls react-optimization in
`--audit-only` mode.

---

## Step 1.5 — Discover project standards & policies (mandatory)

Skip this step when `AUDIT_ONLY` is `true`. Otherwise locate where this project documents its coding standards, conventions, and policies. The optimization plan must not
violate a single one, and the audit itself must not flag a pattern the standards actually mandate.

1. Read the repo-root `README.md` and `AGENTS.md` (and any per-project `AGENTS.md` / `README.md` for `PROJECT_PATH`) and follow every link they make to
   standards/policy/convention documents (e.g. `docs/standards/`, `docs/policies.md`,
   `CONTRIBUTING.md`, a `standards/` directory).
2. If neither file names a standards location, search with `Grep`/`Glob`: `docs/standards/`, `docs/policies*.md`,
   `docs/conventions*.md`, `CONTRIBUTING.md`, `.editorconfig`, `eslint.config.*`, `.prettierrc*`, and any file whose name contains `standard`, `policy`, or `convention`.
3. When the location was not explicitly declared, confirm with the developer which document (s) you believe are the project's standards before relying on them; if you
   find none, say so explicitly.
4. Read them in full and record the concrete rules as `PROJECT_STANDARDS`. Pass this to feature-planning in Step 4 so every optimization step is held against it.

---

## Step 2 — Audit TanStack usage

Systematically search `PROJECT_PATH` for every problem category whose library key is in `TANSTACK_LIBS`. For each hit, **read the actual file to confirm line numbers
before recording**. Never approximate. Confirm library behavior against the installed version in `node_modules/@tanstack/*/package.json` (or that version's official docs)
before prescribing a fix — APIs move between major versions (`cacheTime` → `gcTime`, `keepPreviousData` → `placeholderData`, Query v4 vs v5 status flags).

Record each finding as:

- **Category** (Query / Table / Router / Form / Virtual)
- **Component::hook ()** or module name
- **File path** (exact, relative to repo root)
- **Line range**
- **One-sentence description of the specific problem**

> **Audit method — trace the observers, do not just grep.** The tables catch syntactic hits. The highest-value findings
> (query key missing a variable the `queryFn` closes over, N independent `useQuery` calls that should be `useQueries`,
> a table that remounts every keystroke because `columns` is inline, a loader waterfall) only appear when you read the
> hook, the options it is passed, and the component that owns the state those options close over. For every `useQuery` /
> `useReactTable` / `createRouter` / `useForm` / `useVirtualizer` site, read the full options object and its callers.

### Coexistence rules (Inertia + Query, Router + Query)

On an Inertia host, follow [`../react-optimization/resources/inertia-api-first.md`](../react-optimization/resources/inertia-api-first.md) for every Inertia prop.
`react-optimization --audit-only` (Step 3.5) owns the undocumented-prop ask — do not ask again. If that run produced no inventory, run the file here before Step 4.

- After bootstrap, server interactions go through the project's API data layer (`useQuery` and its query functions).
- Keep a `useQuery` that hits a client-only REST/JSON endpoint on Query.
- Replace `fetch`/`axios` inside `useEffect` (or a hand-rolled cache) for server state with `useQuery`.
- When TanStack Router loaders and Query are both present, the loader calls `queryClient.ensureQueryData` (or the project's equivalent)
  rather than fetching a second, disconnected cache. Flag a loader `fetch` that duplicates a `useQuery` on the same key.

### Query (`@tanstack/react-query`)

| Problem                                               | How to detect (read the call chain)                                                                                                                                                                                                   |
|-------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `QueryClient` created during render                   | `new QueryClient(` inside a function component body, with no `useState(() => ...)` / module-level singleton. Each render gets a new cache.                                                                                            |
| `fetch` / `axios` in `useEffect` for server state     | Effect that writes remote data into `useState`. Replace with `useQuery`.                                                                                                                                                              |
| `queryKey` missing a variable the `queryFn` uses      | `queryFn` closes over `id` / `filters` / `page` that is not in `queryKey`. Treat the key like a `useEffect` dependency array.                                                                                                         |
| Unstable key identity (inline object every render)    | `queryKey: ['x', { ... }]` built from a new object literal each render *and* that object is not derived from primitives. Prefer primitive key parts or a stable factory (`queryOptions`).                                             |
| N `useQuery` inside `.map` / a loop                   | Component maps a list of ids into `useQuery({ queryKey: ['item', id] })`. Use `useQueries({ queries: ids.map(...) })`.                                                                                                                |
| Sequential dependent queries that could start earlier | `const a = useQuery(A); const b = useQuery(B)` where B does not need A, or B is written as `enabled: !!a.data` after an unnecessary `await` in a queryFn. Parallelize independent queries; use `enabled` only for real dependents.    |
| Default `staleTime: 0` on a hot, slow-changing query  | `useQuery` with no `staleTime` (and no `defaultOptions.queries.staleTime` on the client) for settings, permissions, or reference data that refetches on every mount/focus. Set a real `staleTime` (or `'static'` for boot-only data). |
| Query data copied into `useState`                     | `useEffect(() => setX(data), [data])` or `useState(data)` that then becomes the rendered source of truth. This opts out of background updates. Render `data` directly, or set `staleTime` if a one-shot form seed is intentional.     |
| Missing `select` on a large payload                   | Component reads one field (a count, a single row, a boolean) from a large `data` object with no `select`. Subscribe to the derived value so structural sharing can skip the render.                                                   |
| Broad `invalidateQueries()` after a mutation          | `invalidateQueries()` with no `queryKey`, or a key so wide it refetches the entire cache. Invalidate the smallest prefix that is actually stale; prefer `setQueryData` when the mutation response is the new row.                     |
| Mutation that neither updates nor invalidates cache   | `useMutation` with no `onSuccess`/`onSettled` cache write and no `invalidateQueries`. The UI will stay stale until a refetch trigger.                                                                                                 |
| Paginated list snaps to loading on page change        | `useQuery` whose key includes `page` and has no `placeholderData: keepPreviousData` (v4) / `placeholderData: (prev) => prev` (v5).                                                                                                    |
| `enabled` missing on a dependent query                | `useQuery` whose `queryFn` dereferences another query's `data.id` with no `enabled: !!id`.                                                                                                                                            |
| `queryFn` ignores `queryKey` / context                | `queryFn` closes over changing values instead of reading them from `queryKey` (or the query function context). Breaks key-factory reuse.                                                                                              |
| Rest-destructure of the whole query observer          | `const { data, ...rest } = useQuery(...)` — tracked props mark every field dirty (v4 tracked / v5 default). Destructure only the fields the component reads.                                                                          |
| `structuralSharing: false` on a large JSON query      | Explicitly disabled with no comment and no non-JSON payload. Re-enable unless the payload is non-JSON or a profiler named `replaceEqualDeep` as the cost.                                                                             |

Do **not** flag `staleTime: 0` globally as a bug — it is the library default. Flag a *specific* query (or the missing client default) when mount/focus refetch is visibly
wasteful for data that does not change that fast.

### Table (`@tanstack/react-table`)

| Problem                                                           | How to detect (read the call chain)                                                                                                                                                                                                                     |
|-------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `columns` recreated every render                                  | `useReactTable({ columns: [...] })` or `columns` defined inside the component with no `useMemo` / module-level const. Inline `columnHelper` arrays count. Stabilise columns.                                                                            |
| `data` new array identity every render                            | `data: items.map(...)` or `data: [...]` inline in the `useReactTable` call. Memoize or pass a stable reference.                                                                                                                                         |
| Missing `getRowId` on rows that have an id                        | `useReactTable` with no `getRowId` while the row type has `id` / `uuid`. Default index ids remount rows on sort/filter/pagination.                                                                                                                      |
| Unbounded rows rendered into the DOM                              | `table.getRowModel().rows.map(...)` of a list that can exceed ~50 visible rows, with no `@tanstack/react-virtual` (or pagination / windowing). Pair with the Virtual library when it is installed; require pagination or virtualization when it is not. |
| Cell / header renderer defined inside the component               | `cell: (info) => <Cell ...>` closing over render-scoped components (recreates element types). Extract cells to module scope.                                                                                                                            |
| Client-side sort/filter/page of data the server already paginated | `getSortedRowModel` / `getFilteredRowModel` / `getPaginationRowModel` enabled *and* the data is already a single server page, with no `manualSorting` / `manualFiltering` / `manualPagination`. Double work and wrong page counts.                      |
| Grouping / expanding models on a large unvirtualized table        | `getGroupedRowModel` / `getExpandedRowModel` on thousands of rows without virtualization. Confirm against the installed table version before prescribing.                                                                                               |

### Router (`@tanstack/react-router`)

| Problem                                              | How to detect (read the call chain)                                                                                                                                                                                           |
|------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `createRouter` / `new Router` inside render          | Router constructed in a component body. Hoist to module scope.                                                                                                                                                                |
| Route component not code-split                       | File routes without `autoCodeSplitting`, or `createRoute({ component: HeavyPage })` with no `lazy` / `lazyRouteComponent`. Split the component; keep the loader in the parent chunk unless there is a specific reason not to. |
| Loader waterfall                                     | `loader` does `await a()` then `await b()` where `b` does not need `a`. Use `Promise.all` or start `b` before awaiting `a`.                                                                                                   |
| Duplicate fetch: loader + `useQuery` on the same key | Loader calls `fetch` (or a raw client) for data a child also `useQuery`s, without `queryClient.ensureQueryData`. Seed Query from the loader.                                                                                  |
| No preload on likely next routes                     | `<Link>` to primary nav / first list rows with no `preload="intent"` and no router `defaultPreload: 'intent'`.                                                                                                                |
| Default `staleTime: 0` on an expensive loader        | Route `loader` hits the network every navigation with no route/`defaultStaleTime`. Set a real `staleTime` for data that is safe to reuse across navigations.                                                                  |
| Missing pending UI on a slow loader                  | Loader that can take > pendingMs with no `pendingComponent` (and no router-level default). The outlet looks frozen.                                                                                                           |

### Form (`@tanstack/react-form`)

| Problem                                           | How to detect (read the call chain)                                                                                                                                                               |
|---------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Whole-form store subscription on a large form     | `useStore(form.store)` (no selector) or `form.Subscribe` without a selector, in a component that only needs one field or `canSubmit`. Select the slice so sibling fields do not re-render.        |
| `defaultValues` new object every render           | `useForm({ defaultValues: { ... } })` rebuilt from render-scoped literals, causing the form to reset. Hoist or memoize.                                                                           |
| Field validator / listener recreated every render | `validators: { onChange: (v) => ... }` inline on a large form without a stable identity, causing extra validation passes. Extract the validator.                                                  |
| Form used as a server-state cache                 | Form `defaultValues` copied from `useQuery` data *and* then kept as the source of truth across background refetches with no explicit one-shot `staleTime`. Same rule as Query-data-into-useState. |

On an Inertia project, do **not** flag `useForm` from `@inertiajs/react` as a TanStack Form finding. Inertia forms stay on Inertia. Only audit `@tanstack/react-form`.

### Virtual (`@tanstack/react-virtual`)

| Problem                                          | How to detect (read the call chain)                                                                                                                                 |
|--------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Virtualizer without `estimateSize`               | `useVirtualizer({ count, getScrollElement })` missing `estimateSize`. Dynamic measure then has nothing to start from.                                               |
| Rendering `items` instead of `getVirtualItems()` | Component still `.map`s the full source array next to a virtualizer. Only the virtual window should enter the DOM.                                                  |
| `overscan` set very high with no comment         | `overscan` ≥ 20 on a row virtualizer (or ≥ 10 on a grid) without a measured reason. Default/small overscan unless scroll jank was profiled.                         |
| Virtualizer options recreated every render       | `useVirtualizer({ ... })` with inline `estimateSize` / `getScrollElement` that change identity and reset scroll. Stabilize with `useCallback` or a module function. |
| Dynamic-height rows with no `measureElement`     | Variable-height list using a constant `estimateSize` only, causing gaps/overlap. Use `measureElement` (or the installed version's measure API).                     |

---

## Step 3 — Compile TanStack findings

Group findings by library. Count totals. Prepare this structured summary:

```
## Audit results: {PROJECT_NAME}

Project type:    {PROJECT_TYPE}
Project path:    {PROJECT_PATH}
TanStack libs:   {TANSTACK_LIBS}
Test root:       {TEST_ROOT}
Test runner:     {TEST_RUNNER}
Caller context:  {EXTRA_CONTEXT | "(none)"}

Issues found: N total
  Query:    N
  Table:    N
  Router:   N
  Form:     N
  Virtual:  N

### Issues

**Query**
- `Component::hook()` at `path/File.tsx:10-25` — description
[...]

**Table**
[...]

**Router**
[...]

**Form**
[...]

**Virtual**
[...]
```

Omit any library with zero findings (including libraries that are not installed).

---

## Step 3.5 — General React audit

After compiling TanStack findings, run the general React audit on the same path. Call:

```
Skill(react-optimization): {PROJECT_PATH} --audit-only [EXTRA_CONTEXT]
```

The `--audit-only` flag causes react-optimization to stop after its Step 3 — it emits a findings summary and does **not** invoke feature-planning. Capture that summary.

Merge the react-optimization findings into the TanStack audit summary from Step 3:

- Append a new section `**General React**` containing the react-optimization categories (Inertia props, Waterfalls/data, Bundle, Server/props, Client, Re-render,
  Rendering, JavaScript, Advanced).
- Add the react-optimization issue counts to the "Issues found" totals. Carry the Inertia inventory line into the merged summary.
- If a React finding and a TanStack finding cite the same file and overlapping line range, **keep the TanStack finding** (it is the more specific prescription) and drop
  the React one. Typical overlap: `fetch` in `useEffect`
  (React says SWR/`useQuery`; TanStack says `useQuery`). Keep `props-api-first` and `props-api-first-exception` even when the range overlaps — those are the inventory
  decisions, not a generic React rule.
- If react-optimization found zero issues across all categories, note: `General React audit: no issues found.`

The combined summary (TanStack findings + React findings) is what gets passed to feature-planning in Step 4.

---

## Step 4 — Invoke feature-planning (skipped in audit-only mode)

If `AUDIT_ONLY` is `true`, stop here. Emit the merged Step 3 / 3.5 findings summary and return — do not proceed further.

---

Hand off to the **feature-planning skill** with the full merged audit summary as context. Use the following as the feature description passed to feature-planning (feed it
programmatically — do not ask the user to retype it):

---

> Optimization plan for `{PROJECT_NAME}` (`{PROJECT_PATH}`).
>
> Project type: `{PROJECT_TYPE}`
> TanStack libraries: `{TANSTACK_LIBS}`
>
> This is NOT a new feature — it is a performance optimization plan for an existing TanStack + React application. The
> plan must follow the standard feature-planning plan structure with these overrides:
>
> **Replace "Implementation steps" with two phases:**
>
> **Phase 0 — Baseline test coverage (mandatory, non-negotiable)**
> - Run the existing frontend test suite filtered to this project (`{TEST_RUNNER}`). Record all passing tests.
> - If any pre-existing failures exist, stop — they must be fixed before optimization work begins.
> - For every issue in "Issues addressed" with no existing test pinning current behavior, write a baseline test in the project's own runner (Vitest or Jest) using Testing
    Library if the project already uses it.
> - Baseline tests must assert current (pre-optimization) behavior, not desired behavior.
> - Commit baseline tests separately before Phase 1: `test({project}): baseline tests before optimization`
> - Re-run suite. All tests including new baselines must pass before proceeding.
>
> **Phase 1 — Optimizations (one numbered step per issue)**
> - Each step: names file and component/hook, shows exact before/after code snippet, includes a grep/search command to verify no other callers are broken. Use the
    installed TanStack major version's APIs (`gcTime` not `cacheTime` on Query v5, `placeholderData` not `keepPreviousData`, etc.).
> - After every individual step: run the test suite. A single failing test = that step is a failure. Revert and fix before continuing to the next step.
> - One PR per phase.
>
> **Hard constraints to embed in the plan:**
> 1. Every issue cites exact file path and line number range — no approximations.
> 2. Every fix includes a working code snippet using the project's own imports, query-key factories, and conventions.
> 3. Phase 0 is non-negotiable. No Phase 1 step ships without green baseline tests.
> 4. A single test failure after any Phase 1 step = hard stop. Revert, fix, re-run.
> 5. No new infrastructure (no new data library, no SSR mode, no replacement of Inertia with TanStack Router or the reverse). Do not add a TanStack library that is not
     already installed to "fix" a finding — if Table rows are unbounded and Virtual is not installed, paginate or window with what the project already has, or record a
     developer decision before adding `@tanstack/react-virtual`.
> 6. Do not touch files outside `{PROJECT_PATH}` except test files for code inside it, on an Inertia host the specific Laravel controller files a merged React finding
     named, and the standards file a `props-api-first-exception` finding names.
> 7. `new QueryClient()` during render → module-level singleton or `useState(() => new QueryClient())`. No exceptions.
> 8. `fetch`/`axios` in `useEffect` for server state → `useQuery` (Query must already be installed to be in this audit). No exceptions.
> 9. `queryKey` must include every value the `queryFn` reads. No exceptions.
> 10. N `useQuery` calls inside a loop / `.map` → `useQueries`. No exceptions.
> 11. `columns` and `data` passed to `useReactTable` must be referentially stable (`useMemo` or module scope). Rows with an id field must pass `getRowId`. No exceptions.
> 12. `table.getRowModel().rows.map` of an unbounded collection → paginate or virtualize. No exceptions.
> 13. `createRouter` / `new Router` during render → module scope. No exceptions.
> 14. Whole-form `useStore(form.store)` on a multi-field form → a selector for the slice the component reads. No exceptions.
> 15. Honor the Inertia-prop inventory: bootstrap and documented exceptions stay Inertia props; migrate decisions load through the project's Query data layer. Keep
      `@inertiajs/react` `useForm` on Inertia. Keep a client-only `useQuery` on Query.
> 16. Confirm every prescribed API against the installed `@tanstack/*` major version before writing the snippet.
> 17. Honor every hard constraint from react-optimization's plan template for the merged General React findings (inline components, `.sort(` on React data, independent
      `await`s, numeric `&&` JSX, barrel imports, lazy heavy chunks, no Next APIs on Inertia / no Inertia APIs on Next).
>
> 18. Every optimization step must comply with the project's documented standards and policies (see below). No fix may violate a naming, structure, testing, logging,
      dependency, or formatting policy. Where an optimization would conflict with a policy, honor the policy and note the constraint on the step; if the two genuinely
      cannot be reconciled, flag it for developer review rather than shipping the violation.
>
> **Out of scope:** New infrastructure, adding TanStack libraries that are not installed (without an explicit
> developer decision), replacing Inertia with TanStack Router or the reverse, files outside `{PROJECT_PATH}`.
>
> **Project standards & policies to comply with** (discovered in Step 1.5 — the plan must not violate a single rule;
> give these extra attention):
>
> {PROJECT_STANDARDS | "(none found — state this explicitly in the plan)"}
>
> **Caller-supplied context** (treat as authoritative — may describe issues not discoverable by static analysis):
>
> {EXTRA_CONTEXT | "(none provided)"}
>
> **Audit findings to address:**
>
> {FULL_MERGED_AUDIT_SUMMARY_FROM_STEP_3_AND_3_5}

---

The feature-planning skill handles the rest: discovers the planning directory, drafts the plan, applies review lenses, iterates with the user, and writes the final
agent-ready plan to disk.
