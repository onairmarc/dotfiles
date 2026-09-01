---
name: react-optimization
description: Audits a React application or project path for performance issues (render waterfalls, oversized bundles, unnecessary re-renders, derived state in effects, missing virtualization, blocking scripts, undeduplicated client fetches), using vercel-react-best-practices as the rule source — or inertia-best-practices when that skill is present and the project is Inertia — then delegates to the feature-planning skill to produce a self-contained, phased, agent-ready optimization plan. Does NOT execute optimizations. A single failing test in the plan's Phase 0 baseline gate is a hard stop.
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
    - question
---

# React Optimization Skill

You are an expert React performance engineer. Your job is to **audit** a project path, discover performance issues, and then invoke the **feature-planning skill** to
produce a self-contained, agent-ready optimization plan. You do not execute any optimization code yourself.

The audit checklist is **not owned here**. This skill is the audit procedure; the rules live in
`vercel-react-best-practices` (default) or `inertia-best-practices` (Inertia-adapted private fork). Load the selected skill and apply its rules. Do not restate a rule
body in findings — cite the rule slug and describe the concrete hit.

**Input:** `$ARGUMENTS` — the project path to audit (e.g. `resources/js`, `src`, `apps/web`, `resources/js/Pages`).

---

## Step 0 — Validate input

Parse `$ARGUMENTS`. Extract:

- `PROJECT_PATH` — first positional argument (required). If missing or the path does not exist, abort with:
  ```
  Error: PROJECT_PATH is required. Usage: /react-optimization <path/to/project> [additional context]
  ```
- `EXTRA_CONTEXT` — everything after the first positional argument (optional). Free-form text the caller provides about known issues, architectural decisions, or
  constraints the automated audit may not discover (e.g. "the dashboard table always mounts 2k rows", "React Compiler is enabled"). Preserve it verbatim.
- `AUDIT_ONLY` — set to `true` if `EXTRA_CONTEXT` contains the flag `--audit-only`. When set, **stop after Step 3**
  and emit the findings summary. Do **not** invoke feature-planning. This mode is used when react-optimization is called as a sub-audit from another optimization skill
  (e.g. tanstack-optimization) that will handle the feature-planning handoff itself.

Derive `PROJECT_NAME` from the last meaningful path segment (if last segment is `src` or `js`, use its parent).

---

## Step 1 — Detect project type

Read `package.json` at `PROJECT_PATH`, then walk up to the repo root until you find one. Classify:

| Signal                                                                                         | Classification          |
|------------------------------------------------------------------------------------------------|-------------------------|
| `@inertiajs/react` (or `@inertiajs/vue3`) in dependencies, or `Inertia::render` in sibling PHP | **Inertia Application** |
| `next` in dependencies                                                                         | **Next.js Application** |
| `vite` in dependencies and a React entry (`react` + `react-dom`)                               | **Vite React App**      |
| `react` in dependencies, no Next / Inertia / Vite signal                                       | **React Application**   |
| `"type": "module"` library with `react` as a peerDependency and no app entry                   | **React Library**       |

Record as `PROJECT_TYPE`. Scope rules per type:

- **Inertia Application** — in scope: `PROJECT_PATH` plus the Laravel controllers / `HandleInertiaRequests` middleware that render pages living under `PROJECT_PATH`. Out
  of scope: `node_modules/`, `vendor/`, unrelated PHP modules.
- **Next.js Application** — out of scope: `node_modules/`, `.next/`, anything outside `PROJECT_PATH`
- **Vite React App** / **React Application** — out of scope: `node_modules/`, `dist/`, anything outside `PROJECT_PATH`
- **React Library** — out of scope: host application code, `node_modules/`, `dist/`

Determine test root and runner from `package.json` scripts and devDependencies:

- Prefer `vitest`, then `jest`, then the repo's documented frontend test command
- Test root: `{PROJECT_PATH}` colocated tests, `{PROJECT_PATH}/__tests__`, or repo-root `tests/` / `resources/js/tests`

Emit before continuing:

```
Project type: {PROJECT_TYPE}
Project:      {PROJECT_NAME} ({PROJECT_PATH})
Test root:    {TEST_ROOT}
Test runner:  {TEST_RUNNER}
```

If classification is ambiguous, state your best guess and the reason, then continue.

---

## Step 1.5 — Discover project standards & policies (mandatory)

Skip this step when `AUDIT_ONLY` is `true` — the calling skill (e.g. tanstack-optimization) discovers standards and owns the feature-planning handoff. Otherwise locate
where this project documents its coding standards, conventions, and policies. The optimization plan must not violate a single one, and the audit itself must not flag a
pattern the standards actually mandate.

1. Read the repo-root `README.md` and `AGENTS.md` (and any per-project `AGENTS.md` / `README.md` for `PROJECT_PATH`) and follow every link they make to
   standards/policy/convention documents (e.g. `docs/standards/`, `docs/policies.md`,
   `CONTRIBUTING.md`, a `standards/` directory).
2. If neither file names a standards location, search with `Grep`/`Glob`: `docs/standards/`, `docs/policies*.md`,
   `docs/conventions*.md`, `CONTRIBUTING.md`, `.editorconfig`, `eslint.config.*`, `.prettierrc*`, and any file whose name contains `standard`, `policy`, or `convention`.
3. When the location was not explicitly declared, confirm with the developer which document (s) you believe are the project's standards before relying on them; if you
   find none, say so explicitly.
4. Read them in full and record the concrete rules as `PROJECT_STANDARDS`. Pass this to feature-planning in Step 4 so every optimization step is held against it.

---

## Step 1.6 — Select and load the React rules skill (mandatory)

The audit applies the rules from one of two skills. Discover **both** before choosing. Check **repository-level** skills first, then **user-level** skills. A skill is
found when its `SKILL.md` exists.

Search **each** name independently (`inertia-best-practices` and `vercel-react-best-practices`). First hit wins per name, in this order:

1. Current repo: `.agents/skills/**/{name}/SKILL.md`, `skills/{name}/SKILL.md`
2. Sibling checkouts of this repo (the inertia skill is often a **private** fork next to this repo):
   `{repo-parent}/*/.agents/skills/{name}/SKILL.md` and `{repo-parent}/*/agents/skills/{name}/SKILL.md` (e.g.
   `../dotfiles-private/agents/skills/inertia-best-practices/SKILL.md`)
3. User-level, following symlinks: `find -L ~/.config/opencode/skills -name SKILL.md` and keep any path whose parent directory is `{name}`

Use `Bash(test -f *)` / `Glob` / `find -L`. Do not assume a skill is missing because it is absent from this repository.

**Choose `REACT_RULES_SKILL`:**

1. **Both found** — if `PROJECT_TYPE` is **Inertia Application**, use `inertia-best-practices`. Otherwise use
   `vercel-react-best-practices`. The inertia skill is the Vercel guide rewritten for Inertia (no RSC, Laravel props, Vite). Applying it to a Next.js or generic React app
   produces false findings in its data/props/client-visit rules.
2. **Only `inertia-best-practices` found** — use it. If `PROJECT_TYPE` is not Inertia, run only its framework-agnostic sections (re-render, rendering, JavaScript,
   advanced) plus bundle rules that do not require Inertia/Laravel APIs. Skip `data-*`, `props-*`, and Inertia-router `client-*` rules.
3. **Only `vercel-react-best-practices` found** — use it. If `PROJECT_TYPE` is not Next.js, skip `server-*` rules that require RSC, Server Actions, `after()`, or
   `next/dynamic`. Substitute `React.lazy` + `<Suspense>` for
   `bundle-dynamic-imports`.
4. **Neither found** — abort:
   ```
   Error: neither vercel-react-best-practices nor inertia-best-practices is installed (repo or user).
   Install vercel-react-best-practices, or inertia-best-practices for Inertia apps.
   ```

Record `REACT_RULES_SKILL`, `REACT_RULES_SKILL_PATH`, and `RULES_TRACK` (`inertia` or `vercel`).

Read `{REACT_RULES_SKILL_PATH}` in full, then `{dir}/rules/_sections.md` if it exists. Do **not** ingest `AGENTS.md` or every rule file up front — open individual
`rules/{slug}.md` files only when confirming a hit.

Emit before continuing:

```
Rules skill: {REACT_RULES_SKILL} ({REACT_RULES_SKILL_PATH})
Rules track: {RULES_TRACK}
```

---

## Step 2 — Audit the project

Systematically search `PROJECT_PATH` (and, on the inertia track, the related Laravel controllers / share middleware) for every problem category that the selected track
owns. For each hit, **read the actual file to confirm line numbers before recording**. Never approximate. Confirm the hit against the matching rule file under the
selected skill's `rules/`
directory so the finding cites the slug the rule author used.

Record each finding as:

- **Category**
- **Rule slug** (from the selected skill)
- **Component::hook ()** or `Class::method()` (or module name)
- **File path** (exact, relative to repo root)
- **Line range**
- **One-sentence description of the specific problem**

> **Audit method — grep, then read, then walk hot paths.** The tables below catch *syntactic* anti-patterns. After the
> tables, open every page, layout, and list view under `PROJECT_PATH` (Inertia `Pages/`, Next.js `app/` or `pages/`,
> Vite `src/` routes) and apply the remaining rules from the loaded skill that greps miss: sequential awaits that are
> independent, missing Suspense/Deferred boundaries, derived copies of the same payload, oversized serialized props.
> Record hits from BOTH the tables and that walk.

Skip any table whose track does not match `RULES_TRACK`. Skip any row the project-type notes in Step 1.6 marked out of scope. If `@tanstack/react-query` is installed,
still flag undeduplicated client fetches — prescribe `useQuery` rather than SWR. Tanstack-optimization will keep the more specific finding when both skills cite the same
range.

On the inertia track, run [`resources/inertia-api-first.md`](resources/inertia-api-first.md) **before** the `data-*` / `props-*` tables — including when
`AUDIT_ONLY` is true. That file owns classification, the undocumented-prop ask, and which props those tables may still touch.

### Shared — Re-render (both tracks)

| Problem                                            | How to detect                                                                           | Rule slug                                                    |
|----------------------------------------------------|-----------------------------------------------------------------------------------------|--------------------------------------------------------------|
| Component defined inside a component               | A function/const returning JSX declared inside another function component               | `rerender-no-inline-components`                              |
| Derived value stored in state + effect             | `useEffect` whose body only `setState`s from other state/props                          | `rerender-derived-state-no-effect`                           |
| Expensive `useState(compute())` not lazy           | `useState(` followed by a function call that is not `() =>`                             | `rerender-lazy-state-init`                                   |
| `useMemo` around a primitive one-liner             | `useMemo(() => a \|\| b` / simple boolean or number expression                          | `rerender-simple-expression-in-memo`                         |
| Combined `useMemo`/`useEffect` with mixed deps     | One memo/effect that both filters and sorts, or two unrelated side effects              | `rerender-split-combined-hooks`                              |
| Interaction modeled as state + effect              | `useEffect` that fires a POST/navigation because a boolean flipped                      | `rerender-move-effect-to-event`                              |
| Default `[]`/`{}`/`() => {}` on a `memo` component | `memo(` component with a non-primitive default parameter                                | `rerender-memo-with-default-value`                           |
| Effect depends on a whole object                   | `useEffect(..., [user])` when the body only reads `user.id`                             | `rerender-dependencies`                                      |
| High-frequency value in `useState`                 | `setState` inside `scroll`/`mousemove`/`pointermove` without `startTransition` or a ref | `rerender-transitions` / `rerender-use-ref-transient-values` |
| Input + expensive filter without deferral          | Filter/search of a large list keyed directly on the input value, no `useDeferredValue`  | `rerender-use-deferred-value`                                |

### Shared — Rendering (both tracks)

| Problem                                         | How to detect                                                                               | Rule slug                        |
|-------------------------------------------------|---------------------------------------------------------------------------------------------|----------------------------------|
| `{count && <Jsx/>}` where `count` is numeric    | `&&` before JSX and the left operand is a number (or a `.length` used as a count)           | `rendering-conditional-render`   |
| Long list with no `content-visibility` / window | `.map(` over a collection that is not paginated, virtualized, or `content-visibility: auto` | `rendering-content-visibility`   |
| CSS animation applied directly to an `<svg>`    | `className` with `animate-` / `transition` on an `<svg>` element                            | `rendering-animate-svg-wrapper`  |
| Client-only value read during render            | `localStorage` / `window.` read in the component body (Inertia SSR or Next.js)              | `rendering-hydration-no-flicker` |
| Blocking `<script>` without defer/async         | `<script src=` in Blade/`<Head>`/document without `defer` or `async`                        | `rendering-script-defer-async`   |
| Static JSX recreated every render               | Large static SVG/skeleton defined inside the component                                      | `rendering-hoist-jsx`            |

### Shared — JavaScript (both tracks)

| Problem                                       | How to detect                                                                          | Rule slug                                     |
|-----------------------------------------------|----------------------------------------------------------------------------------------|-----------------------------------------------|
| `.sort(` on props, query data, or state       | `.sort(` on an array that originated outside the function (mutates React data)         | `js-tosorted-immutable`                       |
| `.find(` / `.includes(` in a loop or `.map`   | Nested scan of the same collection; no `Map`/`Set` built first                         | `js-index-maps` / `js-set-map-lookups`        |
| `new RegExp` inside render                    | `new RegExp(` in a component body, not module scope and not `useMemo`'d on the pattern | `js-hoist-regexp`                             |
| Interleaved style write + layout read         | `offsetWidth`/`getBoundingClientRect` between `element.style` assignments              | `js-batch-dom-css`                            |
| Chained `.filter().map()` / `.map().filter()` | Two passes where one `flatMap` or one loop would do                                    | `js-flatmap-filter` / `js-combine-iterations` |
| Sort-to-find-min/max                          | `[...arr].sort(...)[0]` to get a single extremum                                       | `js-min-max-loop`                             |

### Shared — Advanced (both tracks)

| Problem                                            | How to detect                                                           | Rule slug                     |
|----------------------------------------------------|-------------------------------------------------------------------------|-------------------------------|
| App-wide init inside `useEffect([])`               | Auth/storage bootstrap in a component effect with no module-level guard | `advanced-init-once`          |
| `useEffectEvent` result listed in effect deps      | `useEffectEvent(...)` identifier appears in a dependency array          | `advanced-effect-event-deps`  |
| Effect re-subscribes when only the handler changes | `addEventListener` in an effect whose deps include a callback prop      | `advanced-event-handler-refs` |

### Shared — Bundle (both tracks; adapt the API to the bundler)

| Problem                                         | How to detect                                                                                                          | Rule slug                                                     |
|-------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| Barrel import of a large icon/component library | `import { ... } from 'lucide-react'` / `@mui/material` / `@mui/icons-material` / `react-icons` / `lodash` / `date-fns` | `bundle-barrel-imports`                                       |
| Heavy editor/chart/map in the page chunk        | Static `import` of Monaco, CodeMirror, a map SDK, a chart lib, a PDF viewer                                            | `bundle-dynamic-imports`                                      |
| Analytics/replay SDK imported at module top     | Top-level `import` of analytics, Sentry replay, session-replay SDKs in the app entry                                   | `bundle-defer-third-party`                                    |
| Dynamic `import(variable)` hiding the path      | `import(someVar)` or `import(map[key])` where `map` values are strings, not `() => import(...)`                        | `bundle-analyzable-paths` (vercel) / treat as Vite equivalent |
| Inertia pages resolved with `{ eager: true }`   | `import.meta.glob(..., { eager: true })` in `createInertiaApp` resolve                                                 | `bundle-code-split-pages` (inertia only)                      |

On the vercel track in Next.js, the prescribed split is `next/dynamic`. On Vite / Inertia, the prescribed split is
`React.lazy` + `<Suspense>`. Never recommend `next/dynamic` outside Next.js.

### Vercel track — Waterfalls (`async-*`)

| Problem                                       | How to detect                                                                      | Rule slug                            |
|-----------------------------------------------|------------------------------------------------------------------------------------|--------------------------------------|
| Sequential `await` of independent calls       | Two `await`s in a row where the second does not use the first's result             | `async-parallel`                     |
| `await` before a cheap guard that often fails | `const flag = await ...` then `if (flag && cheap)`                                 | `async-cheap-condition-before-await` |
| `await` before a branch that does not use it  | Fetch/await above an early return that ignores the result                          | `async-defer-await`                  |
| Page awaits data that only a child needs      | Async page/layout awaits, then renders a large static chrome around one data child | `async-suspense-boundaries`          |
| API route / Server Action await chain         | `await auth()` then `await independentConfig()` then `await fetch(session)`        | `async-api-routes`                   |

### Vercel track — Server (`server-*`) — Next.js only

| Problem                                       | How to detect                                                                         | Rule slug                       |
|-----------------------------------------------|---------------------------------------------------------------------------------------|---------------------------------|
| `"use server"` action with no auth inside     | `'use server'` file/function with no session/auth check before a mutation             | `server-auth-actions`           |
| Full model passed across the RSC boundary     | Server component passes a large object to a `'use client'` child that reads one field | `server-serialization`          |
| Derived copy passed alongside the source      | Same array passed raw and `.toSorted()`/`.filter()`'d as a second prop                | `server-dedup-props`            |
| Nested RSC fetches that wait on the parent    | Child async component declared inside a parent that already awaited                   | `server-parallel-fetching`      |
| Repeated auth/DB helper without `React.cache` | Same `getCurrentUser` / db helper imported and called from multiple server components | `server-cache-react`            |
| Module-level mutable request state            | `let currentUser` (or similar) written during render on the server                    | `server-no-shared-module-state` |

### Vercel track — Client data (`client-*`)

| Problem                                                             | How to detect                                                            | Rule slug                                                         |
|---------------------------------------------------------------------|--------------------------------------------------------------------------|-------------------------------------------------------------------|
| `fetch` / `axios` inside `useEffect` for server state               | Effect that loads remote data into `useState`                            | `client-swr-dedup` (or `useQuery` if TanStack Query is installed) |
| `addEventListener('wheel'`/`touchstart` without `{ passive: true }` | Listener that does not call `preventDefault`                             | `client-passive-event-listeners`                                  |
| Per-instance window listener in a reused hook                       | Hook registers `window.addEventListener` with no module-level registry   | `client-event-listeners`                                          |
| Unversioned `localStorage` of a full object                         | `setItem` of a user/model object with no version prefix and no try/catch | `client-localstorage-schema`                                      |

### Inertia track — Data waterfalls (`data-*`)

Search PHP controllers that `Inertia::render` a page under `PROJECT_PATH`, and the matching page components. Skip any prop the API-first inventory classified as
**migrate**.

| Problem                                         | How to detect                                                                                 | Rule slug                  |
|-------------------------------------------------|-----------------------------------------------------------------------------------------------|----------------------------|
| Page blocks on slow, below-the-fold props       | `Inertia::render` with extra queries and no `Inertia::defer` / `<Deferred>`                   | `data-defer-props`         |
| Expensive hidden prop always evaluated          | Heavy query passed as a plain prop for a tab/panel that is not shown on first paint           | `data-optional-props`      |
| `router.reload()` / visit with no `only`        | `router.reload(` or `router.get(` that refreshes one widget but omits `only:`                 | `data-partial-reloads`     |
| Paginated list replaced instead of merged       | `paginate(` prop without `Inertia::merge` / `deepMerge` on a load-more / infinite-scroll page | `data-merge-props`         |
| Below-the-fold widget fetched up front          | Off-screen section with no `<WhenVisible>` and no `Inertia::optional`                         | `data-when-visible`        |
| `setInterval` + `router.reload()` for live data | Manual interval that reloads the page or all props; no `usePoll`                              | `data-poll-throttle`       |
| N+1 while building props                        | Loop / Resource `toArray` touching a relation that was not `with()`'d                         | `data-parallel-eager-load` |
| Primary nav / first-row links with no prefetch  | Inertia `<Link>` to a frequent next page without `prefetch`                                   | `data-prefetch`            |

### Inertia track — Props (`props-*`)

Apply these rows only to **bootstrap** and **exception** props that remain on the payload after [`resources/inertia-api-first.md`](resources/inertia-api-first.md).

| Problem                                            | How to detect                                                                                         | Rule slug                             |
|----------------------------------------------------|-------------------------------------------------------------------------------------------------------|---------------------------------------|
| Full Eloquent model passed as a prop               | `Inertia::render(..., ['x' => $model])` with no `only` / Resource / DTO                               | `props-minimize-serialization`        |
| Derived copy sent with the source                  | Same collection passed raw and sorted/filtered as a second prop                                       | `props-avoid-duplicate-serialization` |
| Fat `HandleInertiaRequests::share()`               | `share()` returns full user, all permissions, notifications, or eager queries not wrapped in closures | `props-lean-shared-data`              |
| Resource reads a relation that is not eager-loaded | `JsonResource::toArray` accesses `$this->author` / `$this->tags` without a matching `with()`          | `props-avoid-n-plus-one`              |
| Sensitive prop gated only in JSX                   | `{user.isAdmin && <Secrets/>}` while the controller always sends the secrets                          | `props-authorize-server-side`         |

Deep Laravel query work (unbounded `get()`, module-wide N+1, cache, indexes) belongs to `laravel-optimization`. Record the Inertia-facing hit here; do not expand into a
full Laravel audit.

### Inertia track — Client interaction (`client-*`)

| Problem                                                  | How to detect                                                                                     | Rule slug                        |
|----------------------------------------------------------|---------------------------------------------------------------------------------------------------|----------------------------------|
| Plain `<a href>` / `window.location` for an in-app route | `<a href="/...">` or `location.href =` pointing at an Inertia route                               | `client-router-visit-options`    |
| Hand-rolled `fetch` + `useState` form                    | Form submit via `fetch`/`axios` instead of `useForm`                                              | `client-use-form`                |
| Same-page filter remounts the page                       | `router.get` for sort/filter without `preserveState` / `preserveScroll`                           | `client-preserve-state-scroll`   |
| Hand-rolled instant / optimistic visit                   | Custom `router.push` + chained `router.visit` wrapper instead of native `component` / `pageProps` | `client-native-instant-nav`      |
| Wheel/touch listener without `{ passive: true }`         | Same as the shared client row                                                                     | `client-passive-event-listeners` |
| Per-instance window listener                             | Same as the shared client row                                                                     | `client-event-listeners`         |
| Unversioned `localStorage` of a full object              | Same as the shared client row                                                                     | `client-localstorage-schema`     |

---

## Step 3 — Compile findings

Group findings by category. Count totals. Prepare this structured summary:

```
## Audit results: {PROJECT_NAME}

Project type:    {PROJECT_TYPE}
Project path:    {PROJECT_PATH}
Test root:       {TEST_ROOT}
Test runner:     {TEST_RUNNER}
Rules skill:     {REACT_RULES_SKILL} ({RULES_TRACK})
Caller context:  {EXTRA_CONTEXT | "(none)"}

Issues found: N total
  Inertia props:      N
  Waterfalls / data:  N
  Bundle:             N
  Server / props:     N
  Client:             N
  Re-render:          N
  Rendering:          N
  JavaScript:         N
  Advanced:           N

Inertia inventory: {B} bootstrap, {E} exceptions, {U} undocumented (decided)

### Issues

**Inertia props**
- `Class::method()` at `path/Controller.php:10-25` — [props-api-first] description
[...]

**Waterfalls / data**
- `Component::hook()` at `path/File.tsx:10-25` — [rule-slug] description
[...]

**Bundle**
[...]

**Server / props**
[...]

**Client**
[...]

**Re-render**
[...]

**Rendering**
[...]

**JavaScript**
[...]

**Advanced**
[...]
```

Use the category names that the selected track actually produced (e.g. `**Data waterfalls**` on the inertia track,
`**Eliminating waterfalls**` on the vercel track). Omit any category with zero findings. On a non-inertia track, omit the Inertia props category and the inventory line;
on the inertia track, keep the inventory line even when that category is empty.

---

## Step 4 — Invoke feature-planning (skipped in audit-only mode)

If `AUDIT_ONLY` is `true`, stop here. Emit the Step 3 findings summary and return — do not proceed further.

---

Hand off to the **feature-planning skill** with the full audit summary as context. Use the following as the feature description passed to feature-planning (feed it
programmatically — do not ask the user to retype it):

---

> Optimization plan for `{PROJECT_NAME}` (`{PROJECT_PATH}`).
>
> Project type: `{PROJECT_TYPE}`
> Rules skill: `{REACT_RULES_SKILL}` (track `{RULES_TRACK}`)
>
> This is NOT a new feature — it is a performance optimization plan for an existing React project. The plan must follow
> the standard feature-planning plan structure with these overrides:
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
> - Each step: names file and component/hook, shows exact before/after code snippet, includes a grep/search command to verify no other callers are broken. Cite the rule
    slug from `{REACT_RULES_SKILL}`.
> - After every individual step: run the test suite. A single failing test = that step is a failure. Revert and fix before continuing to the next step.
> - One PR per phase.
>
> **Hard constraints to embed in the plan:**
> 1. Every issue cites exact file path and line number range — no approximations.
> 2. Every fix includes a working code snippet using the project's own imports, bundler, and conventions.
> 3. Phase 0 is non-negotiable. No Phase 1 step ships without green baseline tests.
> 4. A single test failure after any Phase 1 step = hard stop. Revert, fix, re-run.
> 5. No new infrastructure (no new SSR mode, no new data library, no RSC migration, no new bundler).
> 6. Do not touch files outside `{PROJECT_PATH}` except test files for code inside it, on the inertia track the specific Laravel controller / share-middleware files the
     finding named, and the standards file a `props-api-first-exception` finding names.
> 7. A component defined inside another component → always extract to module scope and pass props. No exceptions.
> 8. `.sort(` on props, state, or query data → `toSorted()` or a copied array. No exceptions.
> 9. Sequential `await` of independent operations → `Promise.all` (or start-the-promise-early). No exceptions.
> 10. `{n && <Jsx/>}` when `n` is numeric → a boolean condition or ternary. No exceptions.
> 11. Barrel imports of `lucide-react`, `@mui/*`, `@tabler/icons-react`, `react-icons`, `lodash`, `date-fns` → direct subpath imports, or the bundler's documented
      `optimizePackageImports` equivalent. No exceptions.
> 12. Heavy editors/charts/maps in the initial page chunk → `React.lazy` + `<Suspense>` (Vite / Inertia) or
      `next/dynamic` (Next.js only). Never recommend `next/dynamic` outside Next.js. Never recommend `next/script`, Server Actions, `React.cache`, or `after()` on the
      inertia track.
> 13. On the inertia track: in-app `<a href>` / `window.location` → Inertia `<Link>` / `router`. Hand-rolled
      `fetch` forms → `useForm`. Full `router.reload()` for one widget → `only: [...]`. Honor the Inertia-prop inventory: bootstrap and documented exceptions stay props;
      migrate decisions load through the project's API data layer. Keep client-only API reads on that layer.
> 14. On the vercel/Next track: do not recommend `Inertia::defer`, `useForm` from `@inertiajs/react`, or Vite
      `import.meta.glob` page resolution.
> 15. Do not prescribe React Compiler as the fix unless the project already has it enabled; if it is enabled, skip manual `memo`/`useMemo` findings the compiler already
      covers.
> 16. `fetch`/`axios` in `useEffect` for server state → the project's existing data primitive (`useQuery` if
      `@tanstack/react-query` is installed, otherwise SWR on the vercel track). Inertia visit/`useForm` stay the primitive for in-app navigation and forms, not for
      loading page data the inventory sent to the API data layer.
>
> 17. Every optimization step must comply with the project's documented standards and policies (see below). No fix may violate a naming, structure, testing, logging,
      dependency, or formatting policy. Where an optimization would conflict with a policy, honor the policy and note the constraint on the step; if the two genuinely
      cannot be reconciled, flag it for developer review rather than shipping the violation.
>
> **Out of scope:** New infrastructure, SSR/RSC migrations, files outside `{PROJECT_PATH}` (except the named Inertia
> controllers), rewriting the app onto a different meta-framework.
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
> {FULL_AUDIT_SUMMARY_FROM_STEP_3}

---

The feature-planning skill handles the rest: discovers the planning directory, drafts the plan, applies review lenses, iterates with the user, and writes the final
agent-ready plan to disk.
