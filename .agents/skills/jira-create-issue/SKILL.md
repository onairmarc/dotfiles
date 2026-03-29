---
description: Create a Jira issue — invoke when asked to log a bug, task, feature request, improvement, or technical debt ticket in Jira. Handles all required fields, components, and issue-type-specific custom fields automatically.
argument-hint: [ what the ticket is for, issue type if known, project key if known ]
---

Create a Jira issue using the Atlassian MCP tools.

## Step 0 — Discover the Atlassian instance and project

**Cloud ID and site URL:**

Call `mcp__atlassian__getAccessibleAtlassianResources` to retrieve the list of accessible Atlassian sites. If only one
site is returned, use it. If multiple sites are returned, ask the user which one to target.

**Project key:**

If the user has provided a project key (e.g., `MPC`, `ENG`), use it. Otherwise call
`mcp__atlassian__getVisibleJiraProjects` to list available projects and ask the user to choose one.

Store the resolved `cloudId`, `siteUrl`, and `projectKey` — you will need them throughout the remaining steps.

---

## Step 1 — Gather context before creating

If the user has not explicitly stated the issue type, infer it from context:

| User intent                                        | Issue type       |
|----------------------------------------------------|------------------|
| Something is broken / unexpected behaviour         | `Bug`            |
| Net-new capability, user-facing feature            | `Feature`        |
| Improvement to an existing feature                 | `Improvement`    |
| Code cleanup, dead code removal, flag decommission | `Technical Debt` |
| General work item without a clear category         | `Task`           |

Read the current branch, open files, and recent conversation to understand which area of the codebase is affected — use
this to choose components (see Step 2).

---

## Step 2 — Discover and select components

Components are **required** — the ticket will be rejected without them. Pass them as objects in
`additional_fields.components`.

Call `mcp__atlassian__getJiraIssueTypeMetaWithFields` (or `mcp__atlassian__getJiraProjectIssueTypesMetadata`) for the
resolved project to retrieve the list of available components and their IDs. Do not hardcode component IDs — always
fetch them for the target project.

From the fetched list, select all components that apply to the work being described. If the project metadata does not
expose components, ask the user to name the relevant component(s).

---

## Step 3 — Discover issue-type-specific custom fields

Some issue types require additional custom fields. Do not assume field keys — they vary between Jira instances.

Call `mcp__atlassian__getJiraIssueTypeMetaWithFields` for the resolved project and the chosen issue type. Inspect the
response to identify:

- Any required custom fields (marked as `required: true`)
- Their exact field keys (e.g., `customfield_XXXXX`)
- Their expected format (e.g., ADF document, plain string, option object)

Collect values for all required custom fields before proceeding. For fields that expect an ADF document, use the
following structure — **not plain strings**:

```json
{
  "customfield_XXXXX": {
    "version": 1,
    "type": "doc",
    "content": [
      {
        "type": "paragraph",
        "content": [
          {
            "type": "text",
            "text": "Your text here."
          }
        ]
      }
    ]
  }
}
```

Common patterns by issue type (verify field keys against the metadata response — do not use these as hardcoded values):

| User intent                                        | Issue type       |
|----------------------------------------------------|------------------|
| Something is broken / unexpected behaviour         | `Bug`            |
| Net-new capability, user-facing feature            | `Feature`        |
| Improvement to an existing feature                 | `Improvement`    |
| Code cleanup, dead code removal, flag decommission | `Technical Debt` |
| General work item without a clear category         | `Task`           |

---

## Step 4 — Search for related tickets

Before creating the ticket, search Jira for existing issues that may be related. Use
`mcp__atlassian__searchJiraIssuesUsingJql` with a few targeted JQL queries — keyword searches against the summary are
usually sufficient:

```
project = <PROJECT_KEY> AND summary ~ "keyword one" ORDER BY created DESC
project = <PROJECT_KEY> AND summary ~ "keyword two" ORDER BY created DESC
```

Collect up to 5 candidates. Then use `AskUserQuestion` to present the draft and related tickets (see format below). This
begins a **review loop** — repeat until the user explicitly approves creation.

### Review loop

Each iteration:

1. Apply any corrections or additional context the user provided to the draft.
2. If the user provided new context, run fresh JQL searches derived from that context to find additional related
   tickets. Only surface tickets not previously shown — skip any key already presented in a prior round, regardless of
   the user's decision on it.
3. Present the updated draft and any newly found tickets using `AskUserQuestion`.
4. Carry forward all link decisions from previous rounds — do not re-ask about tickets the user has already decided on.
5. If the user approves with no further changes, exit the loop and proceed to Step 5.

### Presentation format

---

**Draft ticket:**
> **[Issue Type]** Summary title here
>
> Description preview (first 2–3 sentences or bullet points)

**New possibly related tickets:** *(omit this section if none were found this round)*

- PRJ-123 — Title of related ticket *(choose: Blocked By / Blocks / Relates To / No link)*
- PRJ-456 — Title of another related ticket *(choose: Blocked By / Blocks / Relates To / Duplicates / No link)* ← offer
  additional types only when context makes them a better fit

**Links confirmed so far:** *(omit if none yet)*

- PRJ-789 — Title → Blocked By

**Before I create this ticket:**

- Does the summary and description look correct, or would you like to change anything?
- For each new ticket listed above, what is the relationship (or no link)?
- Anything else to add, or shall I go ahead and create it?

---

Proceed to Step 5 only once the user confirms the draft is correct and has no further changes.

---

## Step 5 — Call `mcp__atlassian__createJiraIssue`

Always use `contentFormat: "markdown"` for the `description` field. Use ADF objects for custom fields (never markdown
strings for custom fields).

**Minimum required fields:**

```json
{
  "cloudId": "<discovered cloudId>",
  "projectKey": "<resolved projectKey>",
  "issueTypeName": "<Issue type>",
  "summary": "<Concise title>",
  "contentFormat": "markdown",
  "description": "<Markdown body>",
  "additional_fields": {
    "components": [
      {
        "id": "<discovered component id>"
      }
    ]
  }
}
```

---

## Description format

Write the description in Markdown. Structure it as follows (adapt sections to the issue type — omit sections that do not
apply):

```markdown
<One-sentence overview of what needs to be done and why.>

## Background / Context

<Why is this needed? Link to related ticket or feature if relevant.>

## Affected Files

- `path/to/File.ext` — what needs to change and why

## Acceptance Criteria

- Specific, verifiable outcome 1
- Specific, verifiable outcome 2
- All existing tests pass
```

For **Bug** tickets, replace "Affected Files" with:

```markdown
## Steps to Reproduce

1. Step 1
2. Step 2

## Expected Behaviour

<What should happen>

## Actual Behaviour

<What actually happens>
```

---

## Step 6 — Link related tickets (if any were selected)

First, call `mcp__atlassian__getIssueLinkTypes` to retrieve the available link types from Jira.

Map the user's chosen relationship to the correct Jira link type and direction. Prefer these three in the first
instance:

| User chose         | Jira type name | `inwardIssue`  | `outwardIssue` |
|--------------------|----------------|----------------|----------------|
| Blocked By PRJ-XXX | `"Blocks"`     | `PRJ-XXX`      | new ticket key |
| Blocks PRJ-XXX     | `"Blocks"`     | new ticket key | `PRJ-XXX`      |
| Relates To PRJ-XXX | `"Relates"`    | new ticket key | `PRJ-XXX`      |

If the context of a specific relationship suggests a different Jira link type would be more accurate (e.g., "
Duplicates", "Cloners", "Problem/Incident"), offer that alternative to the user alongside the standard three when
presenting the review in Step 4. Only offer link types that are present in the `getIssueLinkTypes` response.

Call `mcp__atlassian__createIssueLink` for each ticket the user chose to link.

---

## Step 7 — Return the result

Return the new ticket URL (`<siteUrl>/browse/<PROJECT_KEY>-XXX`) to the user, along with a one-line summary of any links
that were created.

---

**Task:** $ARGUMENTS