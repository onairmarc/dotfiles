# React domain-state composition

Server-backed domain facts in an Inertia React UI have one canonical TanStack Query owner. Collections retain IDs and collection metadata, while each page composes its
visible model from those records and local UI state.

Duplicating a record in a list, page response, and editor cache allows stale copies to disagree after a mutation. Canonical record keys make the server response the
single persisted value, leaving filters and dialogs as local concerns.

**Rules:**

- Give every independently addressed domain record one canonical query key by stable server ID.
- List, filter, pagination, sort, and membership collections store ordered IDs and collection metadata, not copied record bodies.
- Compose page models locally from canonical record queries. Related domains keep their own records and collection keys.
- Keep unsubmitted form drafts, dialogs, and client-side filters local. A mutation response replaces the matching canonical record; a draft is never persisted state.
- A complete reference catalog may be one canonical collection only when it is the client's sole representation. Its API must paginate, and the collection query must
  aggregate every page before it resolves.
- A page-specific response may include page-only data, but it must not duplicate fields owned by a canonical domain record.
- {{GEN:name this project's canonical query-key convention, mutation reconciliation mechanism, and any allowed reference-catalog exception. Detect the QueryClient setup
and confirm with the user.}}

**Example:**

```ts
// Bad - every surface owns a stale copy of the same server record.
const { data: events } = useQuery({ queryKey: ['events'], queryFn: listEvents });

// Good - the collection owns order and metadata; records have canonical keys.
const { data: eventIds } = useQuery({ queryKey: ['events', filters], queryFn: listEventIds });
const event = useQuery({ queryKey: ['event', eventId], queryFn: () => getEvent(eventId) });
```

> Severity for plan review: **BLOCK**.
