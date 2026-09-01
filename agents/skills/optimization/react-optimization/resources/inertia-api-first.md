# Inertia props are API-first

Canonical inventory for Inertia hosts. `react-optimization` and `tanstack-optimization` both follow this file — one meaning, one ask.

Inertia props carry the **bootstrap** the client needs to start the API data layer. After that, server reads and writes go through that layer (Query `queryFn`s, the
project's API client — not a second, ad-hoc cache). A prop that diverges from API-only is an **exception**
and must be named, with a reason, in `PROJECT_STANDARDS`.

Completion: every Inertia prop under `PROJECT_PATH` is classified, every undocumented non-bootstrap prop has a user decision, and those decisions are recorded as findings
(or explicitly skipped because standards already mandate Inertia-as-the-data-layer).

---

## Classify every prop

Read each `Inertia::render` / `Inertia::share` / `HandleInertiaRequests::share` callsite and the page that consumes it. Grep finds callsites; classification requires the
actual keys and what the page does with them.

| Bucket           | What belongs                                                                                                                                                                                                                                                                                                                                                                      |
|------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **bootstrap**    | Only what the client needs to construct API requests and honor the Inertia protocol. Closed list: protocol fields (`errors`, `flash`, Ziggy/routes, CSRF already on the page); identity **ids** used to build requests (auth user id, tenant/workspace id); tokens the API client requires when they are not in a cookie. Page identity that is already in the URL is not a prop. |
| **exception**    | A non-bootstrap prop that `PROJECT_STANDARDS` names (prop, page, or category) and explains why it stays on the Inertia payload instead of the API data layer.                                                                                                                                                                                                                     |
| **undocumented** | Every other non-bootstrap prop, including a full user/profile, roles, permissions, notifications, collections, tables, dashboard payloads, and any model/Resource sent so the page can render without an API call.                                                                                                                                                                |

A full `auth.user` (or shared permissions, menus, notifications) is **undocumented** unless standards name it. The id alone may be **bootstrap**.

---

## Read exceptions from standards

If `PROJECT_STANDARDS` is not already loaded, scan the same locations Step 1.5 uses (`README.md`, `AGENTS.md`, `docs/standards/`,
`docs/policies*.md`, `docs/conventions*.md`, `CONTRIBUTING.md`, and any path those files name). Record only what this inventory needs:

- A **blanket mandate** that page data travels as Inertia props (the standards treat Inertia as the data layer). Honor it: skip the ask, apply `data-*` / `props-*` to the
  remaining props, and stop this file. Do not invent an API-first finding that contradicts the standards.
- A **named exception list** — honor each named prop/page/category; everything else stays in play.
- **Silence** — API-first applies; every non-bootstrap prop is **undocumented**.

An implied "we use Inertia" is not an exception. The standards must name the divergence and the reason.

---

## Inventory

On the inertia track, run this **before** the `data-*` / `props-*` tables. Run it even when `AUDIT_ONLY` is true.

1. Collect every page-prop and shared-prop key that reaches a page under `PROJECT_PATH`.
2. Classify each key (**bootstrap** / **exception** / **undocumented**).
3. If any key is **undocumented**, ask (below) before compiling findings.
4. Apply `data-*` / `props-*` only to **bootstrap** and **exception** props that remain on the payload. Skip those rows for any prop the user sent to **migrate**.

---

## Ask

Use `question` once per batch (at most 4 questions per call; consolidate). Do not assume a decision.

**Question text** must name the undocumented props (page or `share()`, key, file:line, what the page does with the value), state that API-first is the default, and state
that an exception has to live in project standards with a reason.

**Options** — put the recommended option first and append ` (Recommended)` to its label. Write full descriptions (what happens, tradeoffs, follow-on work):

| Label                    | When chosen                                                                                                                                                                                                                                            |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Migrate to API`         | Those props leave the Inertia payload. The page reads them through the project's API data layer. Record a `props-api-first` finding per prop (or per page when they share one endpoint).                                                               |
| `Document as exceptions` | Props stay on Inertia. Record a `props-api-first-exception` finding to write each named exception plus the user's reason into `PROJECT_STANDARDS`. Then apply `data-*` / `props-*` to them. If the user gives no reason, ask for one before recording. |
| `Decide per page`        | Follow-up questions, one page (or one `share()` surface) at a time, same two outcomes.                                                                                                                                                                 |

**Recommend** with the question criteria, in order:

1. An API data layer is already installed (`@tanstack/react-query`, the project's API client, or equivalent) → **Migrate to API**. Server state stays in one layer.
2. No API data layer is installed → **Document as exceptions**. These skills do not add a data library. If the user still picks migrate, record the finding as blocked on
   a developer decision to adopt a data layer; do not add Query/SWR/a client to "fix" it.

Never move a client-only REST/JSON `useQuery` onto an Inertia prop.

When this file is reached from `tanstack-optimization` **and** that skill will run `react-optimization --audit-only`, the React run owns the ask. TanStack does not ask
again. If that run produced no inventory, the TanStack run executes this file itself before feature-planning.

---

## Findings

| Decision                             | Category      | Slug                        | Plan step                                                                                                                                                                      |
|--------------------------------------|---------------|-----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Migrate                              | Inertia props | `props-api-first`           | Drop the prop from `Inertia::render` / `share()`. Read it through the existing data layer (`useQuery` + the project's query-key factory / API client when Query is installed). |
| Document                             | Inertia props | `props-api-first-exception` | Add the named exception and reason to `PROJECT_STANDARDS`. Keep the prop. Apply `data-*` / `props-*`.                                                                          |
| Bootstrap or already-named exception | —             | —                           | No API-first finding. Apply `data-*` / `props-*` only.                                                                                                                         |

Cite file path and line range from the controller / `share()` callsite. Include the inventory counts in the audit summary:

```
Inertia inventory: {B} bootstrap, {E} exceptions, {U} undocumented (decided)
```
