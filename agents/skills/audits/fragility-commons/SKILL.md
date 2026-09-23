---
name: fragility-commons
description: Canonical contracts for proven failure-path audits and their planning, review, split, execution, and verification handoffs.
---

# Fragility commons

Read only the contract needed for the current stage. These documents keep proven failure-path requirements consistent from audit through execution.

| Concern            | File                                                   | Read it when…                                   |
|--------------------|--------------------------------------------------------|-------------------------------------------------|
| Evidence threshold | [`proof-contract.md`](proof-contract.md)               | auditing or validating a failure chain          |
| Embedded report    | [`report-format.md`](report-format.md)                 | writing or reading a fragility remediation plan |
| Remediation design | [`planning-contract.md`](planning-contract.md)         | creating or resyncing a plan                    |
| Review checks      | [`review-contract.md`](review-contract.md)             | reviewing a plan or audit handoff               |
| Sub-plan handoff   | [`subplan-contract.md`](subplan-contract.md)           | splitting or executing a plan                   |
| Final verification | [`verification-contract.md`](verification-contract.md) | verifying branch changes after implementation   |

These documents define internal workflow contracts. The embedded `## Fragility audit report` is the plan artifact that preserves the audit's rationale.
