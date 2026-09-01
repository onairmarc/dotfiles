# Subsystem Inventory Format

Canonical structure for the subsystem inventory and the coordinator's scratchpad. Both audit skills use this format so findings are comparable across whole-repo and
change-scoped audits.

---

## Subsystem fields

Give each subsystem:

- a stable ID and descriptive name;
- an exact ownership boundary;
- its key implementation files;
- relevant public interfaces, major call sites, and tests;
- a status (see below).

### Status values

| Status      | Meaning                                                                      |
|-------------|------------------------------------------------------------------------------|
| queued      | Identified but not yet reviewed.                                             |
| in review   | A worker is currently inspecting this subsystem.                             |
| recommend   | Review complete; at least one recommendation accepted.                       |
| fix applied | Recommendation implemented (change-audit only; codebase-audit is read-only). |
| skip        | Review complete; nothing met the materiality threshold.                      |

---

## Scratchpad structure

Create one canonical scratchpad or report containing:

- the subsystem inventory;
- confirmed opportunities;
- explicit skip decisions;
- cross-cutting patterns;
- duplicates and superseded findings;
- final priorities and dependencies;
- an audit log.

Treat this inventory as the coverage contract. Do not assume broad catch-all rows prove coverage.
