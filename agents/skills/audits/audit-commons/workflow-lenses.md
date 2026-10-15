# Workflow lenses

This is the single entry point for the cross-cutting code and plan lenses. Read this file once at the review point, then read each linked lens once and evaluate it once.
Do not repeat a lens elsewhere in the same workflow.

This index is read-only guidance. It does not invoke a skill, create a plan, or start another audit. Calling workflows retain control of their own execution order.

## Required lenses

| Lens                  | Canonical guidance                           | Required evaluation                                                                                        |
|-----------------------|----------------------------------------------|------------------------------------------------------------------------------------------------------------|
| 2 AM outage readiness | [`outage-readiness.md`](outage-readiness.md) | Can an on-call engineer understand, diagnose, and safely recover the affected behavior?                    |
| Deletion-first design | [`deletion-first.md`](deletion-first.md)     | Can the same required outcome work with materially less code or fewer concepts?                            |
| Simplicity first      | [`simplicity-first.md`](simplicity-first.md) | What is the minimum safe change, and does an equivalent deletion-first option preserve all other behavior? |

Keep the findings and explicit skips separate by lens. Each lens's file defines its evidence, applicability, and outcome rules.
