---
name: livewire-upgrade-analysis
description: Audits a Laravel repository for custom Livewire components and produces an agent-ready upgrade plan for migrating from Livewire 3 to Livewire 4. Discovers components, classifies required changes by breaking-change category, and writes a structured plan using the feature-planning foundation.
argument-hint: [ target-livewire-version ] [ jira-epic-key ]
allowed-tools:
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
  - WebFetch(domain:laravel.com)
  - WebFetch(domain:*.laravel.com)
model: opus
---

# Livewire Upgrade Analysis

You are a senior Laravel engineer specializing in Livewire and Filament. Your job is to audit the repository's custom
Livewire components **and** custom Filament components (pages, resources, widgets, actions, form components) against
the Livewire 4 breaking-change catalog, classify every affected file, and produce an **agent-ready upgrade plan**
using the same structure and quality bar as `feature-planning`.

**Always present findings to the user for confirmation before writing the plan.**

---

## Inputs

Parse from `$ARGUMENTS`:

| Argument                  | Required | Default | Description                                                 |
|---------------------------|----------|---------|-------------------------------------------------------------|
| `target-livewire-version` | No       | `4`     | The Livewire major version being upgraded to                |
| `jira-epic-key`           | No       | —       | If provided, surface it in the plan header for traceability |

---

## Breaking-change catalog (Livewire 3 → 4)

Use these categories throughout the audit. Each file may hit multiple categories.

### HIGH impact

| ID | Category                         | What to look for                                                                                   |
|----|----------------------------------|----------------------------------------------------------------------------------------------------|
| H1 | **Config restructuring**         | `config/livewire.php` keys: `layout`, `lazy_placeholder`, `smart_wire_keys`                        |
| H2 | **Routing**                      | `Route::get(..., ComponentClass::class)` for full-page components; must become `Route::livewire()` |
| H3 | **wire:model event propagation** | `wire:model` on a wrapper `<div>` expecting child input events; needs `.deep` modifier             |
| H4 | **wire:navigate:scroll**         | `wire:scroll` attribute → `wire:navigate:scroll`                                                   |
| H5 | **Unclosed component tags**      | `<livewire:component-name>` without self-closing `/>`                                              |

### MEDIUM impact

| ID | Category                              | What to look for                                                                              |
|----|---------------------------------------|-----------------------------------------------------------------------------------------------|
| M1 | **wire:model modifier behavior**      | `wire:model.blur` / `wire:model.change` without `.live` prefix                                |
| M2 | **wire:transition modifiers removed** | `.opacity`, `.scale`, `.duration.*`, `.origin.*` on `wire:transition`                         |
| M3 | **stream() signature**                | `$this->stream(to:..., content:..., replace:...)` → positional + `el:` param                  |
| M4 | **Asset URL / firewall rules**        | Hardcoded `/livewire/` paths in CSP headers, nginx rules, `setUpdateRoute`, or JS fetch calls |

### LOW / JS impact

| ID | Category                    | What to look for                                                                      |
|----|-----------------------------|---------------------------------------------------------------------------------------|
| L1 | **$wire.$js() method**      | `$wire.$js('name', fn)` call syntax → property assignment `$wire.$js.name = fn`       |
| L2 | **Global $js()**            | `$js('name', fn)` → property assignment                                               |
| L3 | **Hook system replacement** | `commit` / `request` hooks; `respond()`, `succeed()`, `fail()` callbacks              |
| L4 | **Volt migration**          | `use Livewire\Volt\Component`, `Volt::route()`, `Volt::test()`, `VoltServiceProvider` |

---

## Catalog refresh — Fetch the latest upgrade guide

Before auditing any code, fetch the official Livewire upgrade guide to ensure the breaking-change catalog below
reflects the current published version:

```
https://livewire.laravel.com/docs/4.x/upgrading
```

Use `WebFetch` with a prompt such as:

> "Extract all breaking changes, renamed methods/properties, removed features, new requirements, and migration steps
> for upgrading from Livewire 3 to Livewire 4. Be comprehensive."

Compare the fetched content against the **Breaking-change catalog** section of this skill. For each item in the
fetched guide that is **not** already covered:

1. Add it to the appropriate severity tier (HIGH / MEDIUM / LOW-JS) with a new category ID (e.g. H6, M5, L5).
2. Update the "What to look for" column with the concrete pattern to grep for.
3. Carry the new category IDs forward into Steps 1–3 and the findings table.

If the fetch fails (network unavailable, page unreachable), continue with the embedded catalog and note in the
final plan header: `"Upgrade guide could not be fetched — catalog may be outdated. Verify against
https://livewire.laravel.com/docs/4.x/upgrading before proceeding."`.

---

## Pre-flight — Discover the repo

Before auditing, orient yourself:

1. **Locate Livewire config** — check for `config/livewire.php`.

2. **Detect Livewire component roots** — check for components in these locations (in order):
    - `app/Livewire/`
    - `app/Http/Livewire/`
    - Any path listed under `component_locations` in `config/livewire.php`
    - Subdirectory `app/` variants if this is a monorepo (e.g. `application/app/Livewire/`)

3. **Detect Filament component roots** — search both `app/` and `app_modules/` using Grep:

   Grep for PHP files extending or using core Filament classes:
    ```
    pattern: "extends\s+(Page|Resource|Widget|Action|Cluster|RelationManager|EditRecord|CreateRecord|ListRecords|ViewRecord|ManageRelatedRecords|BaseWidget|ChartWidget|StatsOverviewWidget|TableWidget)"
    paths: app/, app_modules/
    glob: **/*.php
    ```

   Also grep for Filament trait usage:
    ```
    pattern: "use\s+Filament\\\\|HasForms|HasTable|HasActions|HasInfolists|InteractsWithTable|InteractsWithForms"
    paths: app/, app_modules/
    glob: **/*.php
    ```

   Record all discovered paths, grouped by type:
    - **Pages** — files in `*/Filament/Pages/` or extending `Page`
    - **Resources** — files in `*/Filament/Resources/` or extending `Resource`
    - **Widgets** — files in `*/Filament/Widgets/` or extending `*Widget`
    - **Relation managers** — extending `RelationManager` or `ManageRelatedRecords`
    - **Custom form/table components** — extending Filament component base classes
    - **Other** — any remaining matches

4. **Locate views** — find Blade view files that contain `wire:` directives:
   ```bash
   grep -rl "wire:" resources/views --include="*.blade.php"
   ```
   Also find views co-located with class components.

5. **Detect routes** — find route files referencing Livewire components:
   ```bash
   grep -rl "Livewire\|livewire" routes/ --include="*.php"
   ```

6. **Detect JS customizations** — find JS files using Livewire hooks or `$wire`:
   ```bash
   grep -rl "\$wire\|Livewire\.hook\|commit\b\|request\b" resources/js --include="*.js" --include="*.ts"
   ```

7. **Detect Volt** — check for `livewire/volt` in `composer.json` or `composer.lock`.

8. **Detect plan output dir** — check for these in order; use first that exists:
    - `docs/_planning/`
    - `docs/planning/`
    - `planning/`
    - `_planning/`

   Default: `docs/_planning/`. Record as `$PLAN_DIR`.

9. **Read project conventions** — if any of the following exist, read them:
    - `AGENTS.md`
    - `CLAUDE.md`
    - `docs/policies.md`

---

## Step 0 — Confirm scope with user

Use `AskUserQuestion` to present what you found and confirm scope before auditing:

> **Livewire upgrade analysis — scope confirmation**
>
> Found:
> - **Livewire component roots:** [list discovered paths]
> - **Filament components:** [count by type — e.g. 12 pages, 8 resources, 4 widgets, 3 relation managers]
    >

- Searched: `app/`, `app_modules/`

> - **View files with wire: directives:** [count]
> - **Route files referencing Livewire:** [count]
> - **JS files with Livewire hooks:** [count]
> - **Volt detected:** yes / no
>
> Does this look correct? Are there additional component locations or files I should include?

Adjust scope based on the response before proceeding.

---

## Step 1 — Audit each Livewire component class

For every PHP class file discovered in the Livewire component roots:

1. Read the file.
2. Check against categories H2, H3, M3, L4 (class-level concerns).
3. Record findings per file: category ID, affected line(s), current code snippet.

---

## Step 1b — Audit Filament components

For every Filament PHP class file discovered in `app/` and `app_modules/`:

1. Read the file.
2. Check for **direct Livewire API usage** — Filament wraps Livewire internally, but custom code in these files
   may also call Livewire APIs directly. Check for:
    - `$this->stream(...)` — category M3
    - `wire:model` rendered via `->extraAttributes(['wire:model' => ...])` or similar — category H3
    - Any explicit `use Livewire\...` imports other than standard Filament-provided traits
    - `$this->dispatch()` / `$this->dispatchBrowserEvent()` — note: `dispatchBrowserEvent` was removed in
      Livewire 3 → check if still present (would indicate leftover Livewire 2 code to clean up first)
3. Check for **Filament-specific Livewire patterns**:
    - Custom `mount()` method using Livewire lifecycle hooks that changed in v4
    - `#[Reactive]` or `#[Locked]` attributes — confirm they are from `Livewire\Attributes\` not a stale import
    - `$this->js(...)` calls — syntax unchanged but verify against catalog refresh
4. Record findings per file: category ID (use existing IDs where applicable, or prefix `F-` for
   Filament-specific findings), affected line(s), current code snippet.

> **Note:** Standard Filament pages/resources/widgets with no direct Livewire API calls are unlikely to need
> changes for the Livewire upgrade itself — the Filament package handles the Livewire layer. Only custom
> overrides and direct API calls require attention here.

---

## Step 2 — Audit Blade views

For every Blade view file discovered:

1. Read the file.
2. Check against categories H3, H4, H5, M1, M2 (view-level concerns).
3. Record findings per file: category ID, affected line(s), current code snippet.

---

## Step 3 — Audit config, routes, and JS

- **Config** (`config/livewire.php`): check H1.
- **Routes**: check H2.
- **JS files**: check L1, L2, L3.
- **Volt**: check L4.
- **CSP/nginx/asset URLs**: check M4 (search for hardcoded `/livewire/` strings in config, middleware, or infra files).

---

## Step 4 — Build findings table

Produce a table with all affected files:

| File                                      | Category IDs | Severity     | Summary of changes needed                                               |
|-------------------------------------------|--------------|--------------|-------------------------------------------------------------------------|
| `app/Livewire/Dashboard.php`              | H2           | HIGH         | Route must use `Route::livewire()`                                      |
| `resources/views/livewire/form.blade.php` | H3, M1       | HIGH, MEDIUM | `wire:model` on wrapper div needs `.deep`; `.blur` needs `.live` prefix |

Then group by severity:

- **HIGH** — must fix before upgrade will function
- **MEDIUM** — will silently misbehave or look broken without fix
- **LOW / JS** — degraded developer experience or hook behavior

**Stop here. Present findings to user and ask for confirmation before writing the plan.**

Prompt:

> Above are all affected files. Shall I proceed with generating the upgrade plan?
> Reply **yes** to write the plan, or list any corrections first.

---

## Step 5 — Write the upgrade plan

Once confirmed, write the plan to `$PLAN_DIR/livewire-4-upgrade/plan.md`.

Use this structure (aligned with `feature-planning` conventions):

```markdown
# Livewire 4 Upgrade — Implementation Plan

## Goal

Upgrade all custom Livewire components, views, routes, config, and JS integrations from Livewire 3 to Livewire 4,
ensuring the application functions correctly after
`composer require livewire/livewire:^4.0 && php artisan optimize:clear`.

## Jira Epic

<!-- Include only if jira-epic-key was supplied -->
All tasks should be linked to epic **{jira-epic-key}**.

## Out of scope

- Third-party packages' internal Livewire usage (tracked separately via laravel-dependency-tree-upgrade)
- Adoption of new Livewire 4 features (Islands, Deferred loading, wire:sort, etc.) — this plan covers breaking-change
  remediation only

## Affected components

| File | Change type | Summary |
|------|------------|---------|

<!-- Populated from Step 4 findings table -->

## Architecture

### Wire model event propagation (H3)

In Livewire 4, `wire:model` only listens for events on the element itself, not bubbled events from children. Any
`wire:model` on a wrapper `<div>` or `<label>` with a child `<input>` must add the `.deep` modifier.

### wire:model modifier behavior (M1)

`.blur` and `.change` modifiers now control client-side state sync timing, not just network timing. Existing usages of
`wire:model.blur` or `wire:model.change` that expect live server updates must become `wire:model.live.blur` /
`wire:model.live.change`.

### Full-page component routing (H2)

`Route::get('/path', ComponentClass::class)` no longer works for Livewire full-page components. All such routes must be
converted to `Route::livewire('/path', ComponentClass::class)`. Ensure `livewire/livewire` service provider is
registered (automatic in Laravel 11+).

### Config key renames (H1)

The following keys in `config/livewire.php` have been renamed:

| Old key              | New key               |
|----------------------|-----------------------|
| `layout`             | `component_layout`    |
| `lazy_placeholder`   | `component_placeholder` |

`smart_wire_keys` now defaults to `true` — remove explicit `false` values to adopt the default.

### Asset URL changes (M4)

Livewire 4 appends an `APP_KEY`-derived hash to all asset URLs: `/livewire/` → `/livewire-{hash}/`. Update any
CSP headers, nginx allow-lists, or firewall rules accordingly. If `setUpdateRoute` is used, verify the custom path
still resolves.

### wire:transition modifier removal (M2)

All modifiers on `wire:transition` (`.opacity`, `.scale`, `.duration.*`, `.origin.*`) are removed. Plain
`wire:transition` still works for a default fade. Custom transitions must migrate to CSS view-transition classes.

### stream() signature change (M3)

`$this->stream()` parameter order changed. Named parameter `to:` is removed; positional order is now
`(content, replace, el)`.

### Volt removal (L4)

If Volt is in use, migrate class-based Volt components to standard Livewire 4 components and remove the Volt package.
Functional (closure-based) Volt components must be converted to class components or remain if the team chooses to keep
Volt (check compatibility with Livewire 4 first).

### JS hook system (L3)

`commit` and `request` lifecycle hooks are replaced by `interceptMessage` and `interceptRequest`. Callback names
`respond()`, `succeed()`, and `fail()` are renamed as detailed in the JS changes section.

## Implementation steps

### HIGH — must fix before upgrade

<!-- One step per file/group with identical change type -->

1. **Update `config/livewire.php` — key renames (H1)**
   File: `config/livewire.php`
    - Rename `layout` → `component_layout`
    - Rename `lazy_placeholder` → `component_placeholder`
    - Remove or set `smart_wire_keys` to `true` (it is now the default)

2. **Convert full-page routes (H2)**
   For each route file containing `Route::get(..., ComponentClass::class)` for a Livewire component:
    - Replace with `Route::livewire('/path', ComponentClass::class)`
      Affected files: [list from Step 4]

3. **Fix wire:model on wrapper elements (H3)**
   For each view file containing `wire:model` on a non-input element:
    - Add `.deep` modifier: `wire:model="x"` → `wire:model.deep="x"` (or move to the actual input element)
      Affected files: [list from Step 4]

4. **Replace wire:scroll attribute (H4)**
   Find all: `wire:scroll`
   Replace with: `wire:navigate:scroll`
   Affected files: [list from Step 4]

5. **Self-close component tags (H5)**
   Find all: `<livewire:component-name>` (without `/>`)
   Replace with: `<livewire:component-name />`
   Affected files: [list from Step 4]

### MEDIUM — fix to avoid silent regressions

6. **Add .live prefix to wire:model.blur / .change (M1)**
   Find: `wire:model.blur` and `wire:model.change`
   Replace with: `wire:model.live.blur` and `wire:model.live.change`
   Affected files: [list from Step 4]

7. **Remove unsupported wire:transition modifiers (M2)**
   Find: `wire:transition.opacity`, `wire:transition.scale`, `wire:transition.duration.*`, `wire:transition.origin.*`
   Replace with: plain `wire:transition` or remove and use CSS view-transition classes
   Affected files: [list from Step 4]

8. **Update stream() calls (M3)**
   Old: `$this->stream(to: '#el', content: 'x', replace: true)`
   New: `$this->stream('x', replace: true, el: '#el')`
   Affected files: [list from Step 4]

9. **Update asset URL rules (M4)**
    - Search CSP middleware for `/livewire/` path rules and update to allow `/livewire-*/`
    - Search nginx/Apache config stubs in the repo for the same
    - If `Livewire::setUpdateRoute()` is called, verify the custom path is still served correctly

### LOW / JS — fix to restore hook behavior

10. **Migrate $wire.$js() calls (L1 / L2)**
    Old: `$wire.$js('name', fn)` / `$js('name', fn)`
    New: `$wire.$js.name = fn` / `this.$js.name = fn`
    Affected files: [list from Step 4]

11. **Migrate Livewire JS hooks (L3)**
    Old hook → new hook, callback renames:
    - `Livewire.hook('commit', ...)` → `Livewire.hook('interceptMessage', ...)`
        - `respond()` → `onFinish()`
        - `succeed()` → `onSuccess()`
        - `fail()` → `onError()` / `onFailure()`
    - `Livewire.hook('request', ...)` → `Livewire.hook('interceptRequest', ...)`
        - `url` → `request.uri`
        - `respond()` → `onResponse()`
        - `succeed()` → `onSuccess()`
        - `fail()` → `onError()` / `onFailure()`
          Affected files: [list from Step 4]

12. **Remove Volt (L4)** *(skip if Volt not detected)*
    - Replace `use Livewire\Volt\Component` with `use Livewire\Component` in each Volt component
    - Replace `Volt::route()` with `Route::livewire()`
    - Replace `Volt::test()` with `Livewire::test()`
    - Remove `VoltServiceProvider` from `bootstrap/providers.php`
    - Run: `composer remove livewire/volt`

### Final upgrade step

13. **Bump Livewire and clear cache**
    ```bash
    composer require livewire/livewire:^4.0
    php artisan optimize:clear
    ```

## Configuration

No new configuration keys are introduced by this plan. Existing keys renamed per Step 1.

## Migration

No database migrations required.

## Tests

For each implementation step:

- Re-run existing Livewire browser/feature tests after each HIGH step — confirm no regressions before proceeding to
  MEDIUM steps.
- For components with `wire:model` changes (H3, M1): add or update tests asserting that the correct property is
  updated when the input element fires its event.
- For route changes (H2): assert each full-page route returns HTTP 200 and renders the expected component.
- For `stream()` changes (M3): assert streamed content arrives at the correct element.
- For JS hook changes (L3): test in a browser (Dusk or Playwright) — unit tests cannot exercise Livewire JS.

## Documentation updates

- `CLAUDE.md` / `AGENTS.md`: update Livewire version reference from 3 → 4.
- Remove any Volt-related setup instructions if Volt is removed.
- Update any developer onboarding docs that reference `/livewire/` asset URLs.
```

---

## Step 6 — Apply review lenses

Re-read the written plan against all lenses:

### Lens A — Completeness

- Every file from the Step 4 findings table appears in at least one implementation step.
- Every step names the exact file path(s) affected.
- No step uses vague verbs ("handle", "ensure", "update") without saying *how*.

### Lens B — Ordering

- HIGH steps precede MEDIUM steps precede LOW steps.
- The `composer require` step is last.
- No step depends on a state not yet established by a previous step.

### Lens C — Scope

- No new Livewire 4 features are introduced (Islands, Deferred, wire:sort, etc.).
- No refactors beyond what the breaking-change catalog requires.

### Lens D — Missing information

- Every file path is absolute or relative from repo root (not ambiguous).
- JS steps name specific files, not "JS files in general".
- M4 (asset URL) step lists concrete locations checked, not "search everywhere".

If gaps are found, fix them directly in the plan file, then re-read.

---

## Step 7 — Final confirmation

Present:

```
## Analysis complete ✓

**Plan file:** <path to plan.md>
**Livewire components audited:** N
**Filament components audited:** N (pages: X, resources: X, widgets: X, relation managers: X, other: X)
**Views audited:** N
**Breaking changes found:** N (X HIGH, Y MEDIUM, Z LOW/JS)
**Filament-specific findings:** N (F- category IDs, or "none — no direct Livewire API usage detected")
**Implementation steps:** N

Key findings:
- <bullet per HIGH finding>
- <bullet per notable MEDIUM finding>
- <bullet per Filament-specific finding, if any>
```

Then ask:

> The upgrade plan has been written to `<path>`. Would you like to proceed with implementation, or adjust anything
> first?

---

## Guidelines

- **Never invent findings.** Only report what you actually read in files.
- **One source of truth.** All findings live in the plan file after Step 5.
- **Simpler is better.** If a step can be expressed as a find-and-replace, say so — do not dress it up.
- **Do not adopt new features.** This plan covers breaking-change remediation only. Note new features as an
  "out of scope" item.
- **Batch parallel reads.** Read multiple component files in parallel to keep audit time down.