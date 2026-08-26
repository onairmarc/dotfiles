# Paths and Standards Discovery

Canonical path resolution and standards discovery for the planning skills. Resolve these the same way everywhere; do not re-derive the
ladders per skill.

---

## Directory ladders

Resolve each to the **first entry that exists**, falling back to the stated default when none do.

### `$PLAN_DIR` — disposable plans and the ideas backlog

1. `docs/_planning/`
2. `docs/planning/`
3. `planning/`
4. `_planning/`

Default when none exist: `docs/_planning/`.

### `$PRODUCT_DIR` — durable product docs (northstar + discovery briefs)

Always `docs/product/`. This is fixed, not auto-detected, so the northstar and the discovery briefs (`docs/product/discovery/`) always
co-locate under one durable home. Create it on first write if it does not exist. Durable product docs belong here, **never** inside the
disposable `$PLAN_DIR`.

### `$NORTHSTAR` — the product vision document

Locate it, durable home first, legacy locations after:

1. `docs/product/northstar.md`  *(durable home — `$PRODUCT_DIR/northstar.md`)*
2. `$PLAN_DIR/northstar.md`
3. `docs/northstar.md`  *(legacy)*
4. `northstar.md`  *(legacy)*

Record the resolved path as `$NORTHSTAR`. If none exists, record `$NORTHSTAR = null` — every northstar check is then **skipped
silently** rather than inventing vision constraints. When a caller passes an explicit northstar path, use that instead. A northstar found
at a legacy location is migrated into `$PRODUCT_DIR` on the next write.

### `$DISCOVERY_DIR` — durable PM discovery briefs

1. `docs/product/discovery/`
2. `docs/discovery/`
3. `docs/_discovery/`
4. `discovery/`

Default when none exist: `docs/product/discovery/`. Briefs are **durable** documentation — never delete or move a brief during plan
cleanup.

---

## Standards & policy discovery → `$PROJECT_STANDARDS`

A plan is not agent-ready if it violates a single documented project policy, so a planning skill must know what those policies are.
Discover them the same way every time and record the extracted rules as `$PROJECT_STANDARDS`.

1. **Start where standards are usually declared.** Read the repo-root `README.md` and `AGENTS.md` (and any per-module `AGENTS.md` /
   `README.md` covering the area in scope). Follow every link or reference they make to standards, policy, or convention documents (e.g.
   `docs/standards/`, `docs/policies.md`, `CONTRIBUTING.md`, a `standards/` directory).
2. **If neither file names a standards location, search for it** with `Glob`/`Grep`. Likely homes: `docs/standards/`, `docs/policies*.md`,
   `docs/conventions*.md`, `CONTRIBUTING.md`, `.editorconfig`, and linter/formatter configs (`pint.json`, `phpcs.xml`, `.php-cs-fixer*`,
   `.eslintrc*`, `ruff.toml`, `.golangci.yml`, etc.), plus any file whose name contains `standard`, `policy`, or `convention`.
3. **Confirm you found the right standards when they are not explicitly declared.** If the location was not named in `README.md` /
   `AGENTS.md`, do not silently assume — tell the user which document(s) you believe are the project's standards and why, and confirm
   before relying on them. If you find none, say so explicitly rather than proceeding as if the project has no policies.
4. **Read every standard in full and extract the concrete rules** the plan must obey — naming, module/directory structure, testing,
   logging, error handling, dependency policy, migration/DB rules, formatting, and commit/PR policy. Record them as `$PROJECT_STANDARDS`:
   the checklist a standards/policy lens holds the plan against.
