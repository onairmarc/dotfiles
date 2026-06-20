---
name: laravel-dependency-tree-upgrade
description: Pre-configured wrapper around package-dependency-tree-upgrade for Laravel projects. Audits first-party and organization packages in composer.lock to find those that support the current Laravel version but not the next, creates missing SP Projects features under an upgrade initiative (existing or newly created), and records blocker relationships in the correct upgrade order.
disable-model-invocation: true
argument-hint: <next-laravel-version> [parent-feature]
---

This skill is a Laravel-specific wrapper around the `package-dependency-tree-upgrade` skill. It handles the
Laravel/Illuminate constraint conventions and pre-fills the framework package details so you only need to supply the
target version and (optionally) the SP Projects upgrade initiative.

---

## Inputs

| Argument               | Required | Description                                                                                                                     | Example                 |
|------------------------|----------|---------------------------------------------------------------------------------------------------------------------------------|-------------------------|
| `next-laravel-version` | Yes      | The Laravel major version you are upgrading to                                                                                  | `13`                    |
| `parent-feature`       | No       | The SP Projects umbrella feature to group all upgrade features under. If omitted, you will be prompted to select or create one. | `Upgrade to Laravel 13` |

---

## Before you begin — gather project context

Before invoking `package-dependency-tree-upgrade`, collect the following from the project:

### 1. Locate the lockfile

Look for `composer.lock` in the project root, or a subdirectory if this is a monorepo (e.g.
`application/composer.lock`). If unsure, run:

```bash
find . -name "composer.lock" -not -path "*/vendor/*" -maxdepth 3
```

### 2. Identify package prefixes to audit

Read `composer.json` and note the vendor namespaces used for first-party and organization packages (e.g. `acme/`,
`myorg/`). These are the packages your team owns and must upgrade — third-party packages from Packagist are maintained
externally.

### 3. Determine the current Laravel major version

Read `composer.json` and extract the constraint on `laravel/framework`. The current major version is the highest version
currently supported (e.g. `^11|^12` → current is `12`).

### 4. Resolve the SP Projects project

Call `mcp__sp_projects__getProjects` to list your projects and match the one for this repo (infer the name from the
repo or `APP_NAME` in `.env` if unsure). Store the project name or ID to pass as `sp-project`. If the SP Projects MCP is
unavailable, `package-dependency-tree-upgrade` falls back to a manual report.

---

## Laravel-specific conventions to apply throughout

### Framework package constraints

Some packages constrain `laravel/framework` directly; others only constrain individual `illuminate/*` sub-packages (e.g.
`illuminate/support`, `illuminate/database`). Check **both** when classifying packages:

- A package that constrains `illuminate/support: ^11|^12` is equally blocked as one constraining
  `laravel/framework: ^11|^12`
- A package that constrains any `illuminate/*` sub-package to `^{next-version}` is already compatible for that
  sub-package — verify all constrained sub-packages before marking it compatible

### Packages that often need no feature

- Packages with no `laravel/framework` or `illuminate/*` constraints at all — they are framework-agnostic and do not
  block the upgrade
- Packages that already declare `^{next-version}` support — verify by checking the lockfile before skipping

---

## Invoke `package-dependency-tree-upgrade`

Once you have gathered the above context, run the full `package-dependency-tree-upgrade` process with:

- **lockfile:** the path found above
- **prefixes:** the first-party/organization vendor prefixes
- **framework-package:** `laravel/framework` (also check `illuminate/*` sub-packages as described)
- **current-version:** determined from `composer.json`
- **next-version:** `$ARGUMENTS[0]`
- **sp-project:** the SP Projects project name or ID resolved via `mcp__sp_projects__getProjects`
- **parent-feature:** `$ARGUMENTS[1]` if provided — otherwise omit and let `package-dependency-tree-upgrade` Step 0
  handle initiative discovery or creation

Follow all confirmation steps from `package-dependency-tree-upgrade` — present findings before creating features, and
present the dependency graph before recording blocker relationships.

---

## Usage examples

```
/laravel-dependency-tree-upgrade 13 "Upgrade to Laravel 13"
```

```
/laravel-dependency-tree-upgrade 14 "Laravel 14 readiness"
```

```
/laravel-dependency-tree-upgrade 13
```

*(omit the parent feature to be prompted to select an existing initiative or create a new one)*
