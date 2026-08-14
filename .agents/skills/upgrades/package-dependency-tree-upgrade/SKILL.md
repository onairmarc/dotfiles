---
name: package-dependency-tree-upgrade
description: Audits a set of packages in a dependency lockfile to find those that support the current framework version but not the next, cross-references against an SP Projects upgrade initiative for existing features, creates missing features, maps inter-package dependencies, and records features as blockers in the correct upgrade order.
argument-hint: <lockfile-path> <package-prefix(es)> <framework-package> <current-version> <next-version> <sp-project> [parent-feature]
---

You are a dependency upgrade auditor. Your job is to systematically identify which packages need upgrading for a
framework version bump, ensure SP Projects tracks all of them, and wire up the correct blocker relationships so the team
knows what order to tackle them in.

**Always present findings to the user for confirmation before writing anything to SP Projects.**

> **SP Projects MCP tool surface.** The read tools `mcp__sp_projects__getProjects` and `mcp__sp_projects__getFeatures`
> are the stable, documented surface. The write/link tools referenced below (`mcp__sp_projects__createFeature`,
> `mcp__sp_projects__linkFeatures`) follow the same `mcp__sp_projects__*` naming convention but the write API is still
> landing — verify the exact tool names and parameters against the live MCP before relying on them. If a needed SP
> Projects tool is unavailable, fall back to the manual report described in **Graceful fallback** below rather than
> failing.

---

## Inputs

Parse these from `$ARGUMENTS`:

| Argument            | Description                                                                      | Required | Example                 |
|---------------------|----------------------------------------------------------------------------------|----------|-------------------------|
| `lockfile`          | Path to the lockfile to analyze                                                  | Yes      | `composer.lock`         |
| `prefixes`          | Comma-separated package name prefixes to filter on                               | Yes      | `acme/,myorg/`          |
| `framework-package` | The framework/platform package whose version constraint matters                  | Yes      | `laravel/framework`     |
| `current-version`   | The major version the project is currently on                                    | Yes      | `12`                    |
| `next-version`      | The major version you are upgrading to                                           | Yes      | `13`                    |
| `sp-project`        | SP Projects project name or ID — see **Resolving the SP Projects project** below | Yes      | `MyApp`                 |
| `parent-feature`    | The umbrella feature all new features should be grouped under                    | No       | `Upgrade to Laravel 13` |

### Resolving the SP Projects project

Call `mcp__sp_projects__getProjects` to list the accessible projects. Match `sp-project` against the returned project
names or IDs. If exactly one matches, use it and store its ID. If multiple match, ask the user which one to target. If
the tool is unavailable, see **Graceful fallback**.

---

## Step 0 — Resolve the upgrade initiative (parent feature)

If `parent-feature` was provided as an argument, resolve it to a feature in the project (match by name or ID via the
feature list from Step 2) and skip to Step 1.

Otherwise, fetch the project's features with `mcp__sp_projects__getFeatures` and look for an existing umbrella feature
that may already track this upgrade (e.g. a feature whose name contains "Upgrade", the framework name, or the target
version).

Use the `AskUserQuestion` tool to present the candidates and ask the user which feature to group under. Format each
option as `{name} ({status})` (e.g. `Upgrade to Laravel 13 (Planned)`). Include a `new` option at the end. Example
prompt:

> "Should I group the package-upgrade features under an existing initiative, or create a new one?
>
> Existing candidate features:
> - Upgrade to Laravel 13 (Planned)
> - Dependency audit Q1 (In Progress)
>
> Reply with a **feature name**, or type **`new`** to create a fresh umbrella feature."

- If the user picks an existing feature, set `parent-feature` to it and continue to Step 1.
- If the project has no candidate features, skip the list and ask only whether to create a new umbrella feature.

**If the user replies `new` (or there are no existing features to offer):**

Use the `AskUserQuestion` tool to ask:

> "What should the new umbrella feature be titled?"

Create the umbrella feature using `mcp__sp_projects__createFeature` with:

- **Project:** the resolved project ID
- **Name:** the title the user provided
- **Status:** `Planned` (or the project's default planning status)
- **Description:**
  `{framework-package} is currently on v{current-version}. First-party packages need upgrading before the project can move to v{next-version}.`

Set `parent-feature` to the newly created feature and continue to Step 1.

> If the SP Projects model does not support parent/child feature references, treat `parent-feature` as a naming prefix
> and grouping label instead — record the relationship in each child feature's description and in the report.

---

## Step 1 — Identify candidate packages

Read the lockfile and collect every package whose name starts with one of the given prefixes. For each, record:

- Package name
- The constraint(s) on `framework-package` (or any matching wildcard if a wildcard prefix like `illuminate/*` is given)

Classify each package:

| Classification         | Criteria                                                             |
|------------------------|----------------------------------------------------------------------|
| **needs-upgrade**      | Supports `^{current-version}` but does NOT include `^{next-version}` |
| **already-compatible** | Already declares `^{next-version}` support                           |
| **no-constraint**      | Declares no constraint on the framework package (skip)               |

---

## Step 2 — Cross-reference existing SP Projects features

Fetch the project's features with `mcp__sp_projects__getFeatures` using the resolved project ID. If a `parent-feature`
is set and the model supports it, scope the list to that feature's children; otherwise pull the full feature list and
filter by name pattern.

For each existing feature, extract the package name from its name. The expected pattern is:

```
Upgrade {package} to support {framework} {version}
```

Produce a list of **needs-upgrade** packages that have **no** existing feature.

---

## Step 3 — Present findings and confirm

Show the user a table with three sections:

1. **Already tracked** — needs-upgrade packages that already have a feature (feature name + status)
2. **Missing features** — needs-upgrade packages with no feature (package name + current constraint)
3. **Already compatible** — packages that already support the next version (no action needed)

**Stop here. Ask the user to confirm before creating any features.**

---

## Step 4 — Create missing features

For each package without a feature, create an SP Projects feature with `mcp__sp_projects__createFeature`:

- **Project:** the resolved project ID
- **Parent:** `{parent-feature}` (if the model supports parent references; otherwise prefix the name and note it in the
  description)
- **Name:** `Upgrade {package} to support {framework-package} {next-version}`
- **Status:** `Planned` (or the project's default planning status)
- **Description:**
  `The {package} package constrains {framework-package} to {current constraint}, blocking the upgrade to {next-version}. Update the constraint from {current constraint} to {current constraint}|^{next-version}, verify compatibility, and release a new version.`

Record the newly created feature ID for each package. Batch the create calls where the API allows it.

> **Feature shape:** SP Projects features are name + status + description. There are no required components, issue
> types, or rich-text fields to discover — so there is no field-metadata discovery step. If the live SP Projects schema
> requires additional fields, a create call will surface the error; resolve the missing field and retry.

---

## Step 5 — Map inter-package dependencies

Re-read the lockfile. For every package in the **full feature list** (existing + newly created), look at its `require`
section and record only dependencies that are also in the feature list.

This produces directed edges: `A requires B` means **B must be upgraded before A**.

Present the dependency graph to the user as upgrade tiers:

- **Tier 1:** Packages with no intra-list dependencies — upgrade these first
- **Tier 2+:** Packages whose blockers are all in a prior tier

Include the proposed blocker relationships in a table:

| Blocker (must upgrade first) | Blocked (depends on blocker) |
|------------------------------|------------------------------|
| `package-b (feature)`        | `package-a (feature)`        |

> **Note on pass-through packages:** If a package in the dependency chain does not have a feature (e.g. it has no Laravel
> constraint and was skipped), treat its dependencies as direct dependencies of the packages that require it. This
> preserves the transitive blocking relationship.

**Stop here. Ask the user to confirm before recording any blocker relationships.**

---

## Step 6 — Record blocker relationships

For each confirmed `A requires B` relationship (where both have features), record that B blocks A using
`mcp__sp_projects__linkFeatures`:

- **Relationship:** `blocks` (B blocks A) / `depends-on` (A depends on B) — use whichever direction the SP Projects link
  API expresses
- **Blocker:** B's feature ID
- **Blocked:** A's feature ID

Before recording, check each feature for an existing blocker relationship and skip any pair already linked to avoid
duplicates. Only record **direct** dependency links — do not add transitive links already implied by the chain (if A→B
and B→C, you do not need A→C).

> If SP Projects has no feature-to-feature link API, encode the order in each feature's description
> (`Blocked by: {blocker feature} — upgrade first`) and rely on the tier table from Step 5 as the authoritative upgrade
> order. Note this limitation to the user.

---

## Step 7 — Return the result

Return the list of created features (name + ID) and the recorded blocker relationships, along with the upgrade-tier
order so the team knows what to tackle first.

---

## Graceful fallback — SP Projects unavailable

If `mcp__sp_projects__getProjects`/`getFeatures` are unavailable, or the write/link tools are not yet implemented:

1. Record the tool as unavailable and inform the user in one line ("SP Projects MCP is not available — I'll produce a
   manual report instead.").
2. Run all analysis steps that do not need the tracker (Steps 1 and 5 — package classification and dependency tiers).
3. Emit a Markdown report listing: needs-upgrade packages with their current constraints, the upgrade tiers, and the
   proposed blocker relationships — everything you would have created in SP Projects, so the user can act on it
   manually or replay it once the write API is available.

---

## Important guidelines

- **Never write to SP Projects without user confirmation** — always present findings and pause at Steps 3 and 5.
- **Use the lockfile, not the manifest** — the lockfile contains the resolved, installed versions and their actual
  constraints; the manifest only shows what the root project requires.
- **Batch parallel requests where possible** — feature creation and link creation can be parallelised for speed.
- **Verify SP Projects write/link tool names** against the live MCP before relying on them — the read tools are stable,
  the write API is still landing.
