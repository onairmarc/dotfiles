# Universal PM Lenses

The four universal lenses both pm-review modes apply to every product. They are the shared taxonomy; each mode applies them from its own
direction:

- **Discovery** (before code): ask each lens **forward-looking** — what *would* this idea need, capture, or put at risk?
- **Review** (after code): ask each lens **backward-looking** — does the change in front of you actually handle this?

Beyond these four, always also apply the knowledge base's `invariants` and every `custom_lenses` entry (plus any additional lenses its
front matter declares) — those are product-specific and live in the knowledge base, not here.

---

## U1. Compliance, Privacy & Data Protection

- PII captured, exposed, or moved.
- Consent / opt-in recorded, with timestamps where required.
- Right-to-deletion, data-retention rules, and an audit trail (create/edit/delete with actor + timestamp).
- Regulatory obligations for the product's jurisdiction — GDPR/CCPA and any domain-specific rules — still satisfied.

## U2. Access Control & Multi-Tenant Isolation

- Who is allowed to do this; whether new roles/permissions are needed, and whether new routes, actions, and endpoints carry the correct
  role/permission checks.
- Authorization enforced at the query/data layer, not just hidden in the UI.
- Tenant scoping on new queries and models; no leak across tenant boundaries, including via shared infrastructure (search indexes, caches,
  media/CDN, queues).

## U3. UX & Feature Completeness

- The minimum lovable version for the affected persona, and sensible defaults for that persona.
- Empty / zero / boundary states designed (no records, nothing selected, limits hit).
- End-user error messages that are actionable and free of developer jargon.
- Completeness gaps a user would immediately notice — is it complete enough to ship?

## U4. Metrics, Analytics & Performance

- Which `success_metrics` this moves, and how we would know — the events that must be tracked, with attribution accuracy preserved and
  bot-vs-human traffic handled where it matters.
- Bulk/expensive work run asynchronously (queues/jobs) rather than inline.
- Large-dataset paths at risk of N+1, unbounded queries, or timeouts.
