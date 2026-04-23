---
name: package-dependency-tree-upgrade
description: Audits a set of packages in a dependency lockfile to find those that support the current framework version but not the next, cross-references against a Jira epic for existing tickets, creates missing tickets, maps inter-package dependencies, and links tickets as blockers in the correct upgrade order.
argument-hint: <lockfile-path> <package-prefix(es)> <framework-package> <current-version> <next-version> <jira-cloud-id> <jira-project-key> [jira-epic-key]
---

You are a dependency upgrade auditor. Your job is to systematically identify which packages need upgrading for a
framework version bump, ensure Jira tracks all of them, and wire up the correct blocker relationships so the team knows
what order to tackle them in.

**Always present findings to the user for confirmation before writing anything to Jira.**

---

## Inputs

Parse these from `$ARGUMENTS`:

| Argument            | Description                                                     | Required | Example             |
|---------------------|-----------------------------------------------------------------|----------|---------------------|
| `lockfile`          | Path to the lockfile to analyze                                 | Yes      | `composer.lock`     |
| `prefixes`          | Comma-separated package name prefixes to filter on              | Yes      | `acme/,myorg/`      |
| `framework-package` | The framework/platform package whose version constraint matters | Yes      | `laravel/framework` |
| `current-version`   | The major version the project is currently on                   | Yes      | `12`                |
| `next-version`      | The major version you are upgrading to                          | Yes      | `13`                |
| `jira-cloud-id`     | Atlassian Cloud ID — see **Finding your Jira Cloud ID** below   | Yes      | `a1b2c3d4-...`      |
| `jira-project-key`  | Jira project key                                                | Yes      | `MYAPP`             |
| `jira-epic-key`     | The epic all new tickets should be linked to                    | No       | `MYAPP-100`         |

### Finding your Jira Cloud ID

If you don't know the cloud ID, use the `getAccessibleAtlassianResources` Atlassian MCP tool — it returns a list of
sites with their IDs and URLs. Alternatively, it can often be inferred from the site URL (e.g.
`https://myorg.atlassian.net` → pass `myorg.atlassian.net` as the cloud ID and the tool will resolve it).

---

## Step 0 — Resolve the target epic

If `jira-epic-key` was provided as an argument, skip to Step 1.

Otherwise, use `mcp__atlassian__searchJiraIssuesUsingJql` to search for open epics in the project that may already
track this upgrade:

```jql
project = "{project-key}" AND issuetype = Epic AND statusCategory != Done ORDER BY created DESC
```

Use the `AskUserQuestion` tool to present the results and ask the user which epic to use. Format each option as
`{key}: {summary}` (e.g. `MYAPP-42: Upgrade to Laravel 13`). Include a `new` option at the end. Example prompt:

> "Should I link tickets to an existing epic, or create a new one?
>
> Existing open epics:
> - MYAPP-42: Upgrade to Laravel 13
> - MYAPP-38: Dependency audit Q1
>
> Reply with a **ticket key** (e.g. `MYAPP-42`), or type **`new`** to create a fresh epic."

- If the user provides a key, set `jira-epic-key` to that value and continue to Step 1.
- If the search returns no results, skip the list and ask only whether to create a new epic.

**If the user replies `new` (or there are no existing epics to offer):**

Use the `AskUserQuestion` tool to ask:

> "What should the new epic be titled?"

Before creating the epic, discover its required fields using `mcp__atlassian__getJiraIssueTypeMetaWithFields` for the
Epic issue type in `{project-key}`. For each required field, attempt to infer an appropriate value from context before
asking the user:

| Field type                      | How to infer                                                                                                                                   |
|---------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Summary / title                 | Use the title the user just provided                                                                                                           |
| Components                      | Infer from the lockfile path or repo name (e.g. a `composer.lock` in a repo named `myapp-api` → look for a component named `api` or `backend`) |
| "Current State" or equivalent   | `"{framework-package} is currently on v{current-version}. Packages need upgrading before the project can move to v{next-version}."`            |
| "Desired Outcome" or equivalent | `"All first-party packages support {framework-package} ^{next-version}, unblocking the framework upgrade."`                                    |
| Assignee / reporter             | Leave unset unless inferable from git config (`git config user.email`) matched via `mcp__atlassian__lookupJiraAccountId`                       |
| Any other required field        | Leave unset for now — collect a list                                                                                                           |

If any required fields remain unresolved after inference, use a **single** `AskUserQuestion` call to ask about all of
them at once rather than asking one at a time.

Once all required fields are known, create the epic using `mcp__atlassian__createJiraIssue` with:

- **Type:** Epic
- **Summary:** the title the user provided
- **Project:** `{project-key}`
- All other required fields populated as determined above

Set `jira-epic-key` to the newly created epic key and continue to Step 1.

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

## Step 2 — Cross-reference existing Jira tickets

Search the epic for existing tickets. Jira has two different parent-field conventions depending on project type — try
both and union the results:

```jql
project = "{project-key}" AND "Epic Link" = "{epic-key}"
```

```jql
project = "{project-key}" AND parent = "{epic-key}"
```

For each existing ticket, extract the package name from its summary. The expected pattern is:

```
Upgrade {package} to support {framework} {version}
```

Produce a list of **needs-upgrade** packages that have **no** existing ticket.

---

## Step 3 — Present findings and confirm

Show the user a table with three sections:

1. **Already tracked** — needs-upgrade packages that already have a ticket (ticket key + summary)
2. **Missing tickets** — needs-upgrade packages with no ticket (package name + current constraint)
3. **Already compatible** — packages that already support the next version (no action needed)

**Stop here. Ask the user to confirm before creating any tickets.**

---

## Step 4 — Discover ticket field requirements

Before creating tickets you need to know the required fields, component IDs, Epic Link field key, and ADF structure for
rich-text fields. Use whichever source is available:

**If existing tickets were found in Step 2** — use `mcp__atlassian__getJiraIssue` on any one of them, requesting all
fields. Record:

- All non-null custom field IDs and their values (these are candidates for required fields)
- The field key used to link to the epic (whichever of `customfield_10014`, `parent`, or another field is populated
  with the epic key) — this is the **epic link field key** to reuse in Step 5
- Component IDs (the `id` values from the `components` array)
- The ADF structure of any rich-text fields

**If no existing tickets exist** (brand-new epic) — use `mcp__atlassian__getJiraIssueTypeMetaWithFields` for the
target issue type in `{project-key}` to discover required fields and their schemas. Note that you will not have
real component IDs or ADF examples from this source; defer component selection and rich-text formatting to the
patterns established in Step 0 (epic creation) if available, otherwise omit and handle any `400` response by
retrying with the missing fields resolved.

> **Why this matters:** Jira projects often require custom fields (e.g. "Current State", "Desired Outcome") and
> components. Attempting to create a ticket without required fields will return a `400 Bad Request`.

---

## Step 5 — Create missing tickets

For each package without a ticket, create a Jira issue matching the field structure discovered in Step 4:

- **Type:** Technical Debt (or the type used by existing tickets in the epic)
- **Summary:** `Upgrade {package} to support {framework-package} {next-version}`
- **Epic Link:** `{epic-key}` (use the **epic link field key** discovered in Step 4, not a hardcoded value)
- **Components:** use the same component IDs found in Step 4
- **Current State field:**
  `The {package} package constrains {framework-package} to {current constraint}, blocking the upgrade to {next-version}.`
- **Desired Outcome field:**
  `Update the dependency constraint from {current constraint} to {current constraint}|^{next-version}, verify compatibility, and release a new version.`

Record the newly created ticket key for each package.

---

## Step 6 — Map inter-package dependencies

Re-read the lockfile. For every package in the **full ticket list** (existing + newly created), look at its `require`
section and record only dependencies that are also in the ticket list.

This produces directed edges: `A requires B` means **B must be upgraded before A**.

Present the dependency graph to the user as upgrade tiers:

- **Tier 1:** Packages with no intra-list dependencies — upgrade these first
- **Tier 2+:** Packages whose blockers are all in a prior tier

Include the proposed Jira blocker links in a table:

| Blocker (must upgrade first) | Blocked (depends on blocker) |
|------------------------------|------------------------------|
| `TICKET-X (package-b)`       | `TICKET-Y (package-a)`       |

> **Note on pass-through packages:** If a package in the dependency chain does not have a ticket (e.g. it has no Laravel
> constraint and was skipped), treat its dependencies as direct dependencies of the packages that require it. This
> preserves the transitive blocking relationship in Jira.

**Stop here. Ask the user to confirm before creating any links.**

---

## Step 7 — Create Jira blocker links

Before creating links, fetch the current links on each ticket using `mcp__atlassian__getJiraIssue` to check for
existing blocker relationships. Skip any pair that already has the correct `Blocks` link to avoid duplicates.

For each confirmed `A requires B` relationship (where both have tickets) that is not already linked, create an issue
link using `mcp__atlassian__createIssueLink`:

- **Type:** `Blocks`
- **Inward issue (the blocker):** B's ticket key
- **Outward issue (the blocked):** A's ticket key

> Verify the inward/outward direction with `mcp__atlassian__getIssueLinkTypes` if unsure — the descriptions on the
> link type confirm which side is the blocker.

Only create **direct** dependency links. Do not add transitive links that are already implied by the chain (if A→B and
B→C, you do not need A→C).

---

## Important guidelines

- **Never write to Jira without user confirmation** — always present findings and pause at Steps 3 and 6.
- **Use the lockfile, not the manifest** — the lockfile contains the resolved, installed versions and their actual
  constraints; the manifest only shows what the root project requires.
- **Re-use field values from existing tickets** — do not guess required fields; inspect an existing ticket in the epic
  first.
- **Batch parallel requests where possible** — ticket creation and link creation can be parallelised for speed.